/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 * Contributors: https://github.com/opentibiabr/canary/graphs/contributors
 * Website: https://docs.opentibiabr.com/
 */

#include "server/network/protocol/protocollogin.hpp"

#include "config/configmanager.hpp"
#include "server/network/message/outputmessage.hpp"
#include "game/scheduling/dispatcher.hpp"
#include "account/account.hpp"
#include "creatures/players/livestream/livestream.hpp"
#include "creatures/players/player.hpp"
#include "io/iologindata.hpp"
#include "creatures/players/management/ban.hpp"
#include "game/game.hpp"
#include "core.hpp"
#include "enums/account_errors.hpp"
#include "utils/tools.hpp"

void ProtocolLogin::disconnectClient(const std::string &message) const {
	const auto output = OutputMessagePool::getOutputMessage();

	output->addByte(0x0B);
	output->addString(message);
	send(output);

	disconnect();
}

// LoginServerTokenError (13, see modules/gamelib/protocollogin.lua on the
// client) - the client already shows "Invalid authenticator token." on its
// own for this opcode, so the only payload is a single filler byte.
void ProtocolLogin::disconnectClientInvalidToken() const {
	const auto output = OutputMessagePool::getOutputMessage();

	output->addByte(0x0D);
	output->addByte(0x00);
	send(output);

	disconnect();
}

void ProtocolLogin::getCharacterList(const std::string &accountDescriptor, const std::string &password, const std::string &token) const {
	Account account(accountDescriptor);
	account.setProtocolCompat(oldProtocol);

	if (oldProtocol && !g_configManager().getBoolean(OLD_PROTOCOL)) {
		disconnectClient(fmt::format("Only protocol version {}.{} is allowed.", CLIENT_VERSION_UPPER, CLIENT_VERSION_LOWER));
		return;
	} else if (!oldProtocol) {
		disconnectClient(fmt::format("Only protocol version {}.{} or outdated 11.00 is allowed.", CLIENT_VERSION_UPPER, CLIENT_VERSION_LOWER));
		return;
	}

	if (account.load() != AccountErrors_t::Ok || !account.authenticate(password)) {
		std::ostringstream ss;
		ss << (oldProtocol ? "Username" : "Email") << " or password is not correct.";
		disconnectClient(ss.str());
		return;
	}

	if (account.isTotpEnabled() && !verifyTotpToken(account.getTotpSecret(), token)) {
		disconnectClientInvalidToken();
		return;
	}

	auto output = OutputMessagePool::getOutputMessage();
	const std::string &motd = g_configManager().getString(SERVER_MOTD);
	if (!motd.empty()) {
		// Add MOTD
		output->addByte(0x14);

		std::ostringstream ss;
		ss << g_game().getMotdNum() << "\n"
		   << motd;
		output->addString(ss.str());
	}

	// Add session key
	output->addByte(0x28);
	output->addString(accountDescriptor + "\n" + password);

	// Add char list
	auto [players, result] = account.getAccountPlayers();
	if (AccountErrors_t::Ok != result) {
		g_logger().warn("Account[{}] failed to load players!", account.getID());
	}

	output->addByte(0x64);

	output->addByte(1); // number of worlds

	output->addByte(0); // world id
	output->addString(g_configManager().getString(SERVER_NAME));
	output->addString(g_configManager().getString(IP));

	output->add<uint16_t>(g_configManager().getNumber(GAME_PORT));

	output->addByte(0);

	uint8_t size = std::min<size_t>(std::numeric_limits<uint8_t>::max(), players.size());
	output->addByte(size);
	for (const auto &[name, deletion] : players) {
		output->addByte(0);
		output->addString(name);
	}

	// Get premium days, check is premium and get lastday
	output->addByte(account.getPremiumRemainingDays());
	output->addByte(account.getPremiumLastDay() > getTimeNow());
	output->add<uint32_t>(account.getPremiumLastDay());

	send(output);

	disconnect();
}

void ProtocolLogin::onRecvFirstMessage(NetworkMessage &msg) {
	if (g_game().getGameState() == GAME_STATE_SHUTDOWN) {
		disconnect();
		return;
	}

	msg.skipBytes(2); // client OS

	auto version = msg.get<uint16_t>();

	// Old protocol support
	oldProtocol = version == 1100;

	msg.skipBytes(17);
	/*
	 - Skipped bytes:
	 - 4 bytes: client version (971+)
	 - 12 bytes: dat, spr, pic signatures (4 bytes each)
	 - 1 byte: preview world(971+)
	 */

	const uint32_t rsaBlock1Start = msg.getBufferPosition();
	if (!Protocol::RSA_decrypt(msg)) {
		g_logger().warn("[ProtocolLogin::onRecvFirstMessage] - RSA Decrypt Failed");
		disconnect();
		return;
	}

	std::array<uint32_t, 4> key = { msg.get<uint32_t>(), msg.get<uint32_t>(), msg.get<uint32_t>(), msg.get<uint32_t>() };
	enableXTEAEncryption();
	setXTEAKey(key.data());

	setChecksumMethod(CHECKSUM_METHOD_ADLER32);

	if (g_game().getGameState() == GAME_STATE_STARTUP) {
		disconnectClient("Gameworld is starting up. Please wait.");
		return;
	}

	if (g_game().getGameState() == GAME_STATE_MAINTAIN) {
		disconnectClient("Gameworld is under maintenance.\nPlease re-connect in a while.");
		return;
	}

	BanInfo banInfo;
	auto curConnection = getConnection();
	if (!curConnection) {
		return;
	}

	if (IOBan::isIpBanned(curConnection->getIP(), banInfo)) {
		if (banInfo.reason.empty()) {
			banInfo.reason = "(none)";
		}

		std::ostringstream ss;
		ss << "Your IP has been banned until " << formatDateShort(banInfo.expiresAt) << " by " << banInfo.bannedBy << ".\n\nReason specified:\n"
		   << banInfo.reason;
		disconnectClient(ss.str());
		return;
	}

	std::string accountDescriptor = msg.getString();
	if (accountDescriptor.empty()) {
		std::ostringstream ss;
		ss << "Invalid " << (oldProtocol ? "username" : "email") << ".";
		disconnectClient(ss.str());
		return;
	}

	std::string password = msg.getString();
	if (accountDescriptor == "@livestream") {
		if (oldProtocol && !g_configManager().getBoolean(OLD_PROTOCOL)) {
			disconnectClient(fmt::format("Only protocol version {}.{} is allowed.", CLIENT_VERSION_UPPER, CLIENT_VERSION_LOWER));
			return;
		} else if (!oldProtocol) {
			disconnectClient(fmt::format("Only protocol version {}.{} or outdated 11.00 is allowed.", CLIENT_VERSION_UPPER, CLIENT_VERSION_LOWER));
			return;
		}

		g_dispatcher().addEvent(
			[self = std::static_pointer_cast<ProtocolLogin>(shared_from_this()), password] {
				self->getLivestreamCharacterList(password);
			},
			"ProtocolLogin::getLivestreamCharacterList"
		);
		return;
	}

	if (password.empty()) {
		disconnectClient("Invalid password.");
		return;
	}

	// The account/password read above only consumes as many bytes as their
	// content needs, not the full 128-byte RSA block (the rest is random
	// padding). Skip to the actual end of the block before reading anything
	// else, or every read past this point would be misaligned.
	constexpr uint32_t RSA_BLOCK_SIZE = 128;
	msg.skipBytes(static_cast<int16_t>(RSA_BLOCK_SIZE - (msg.getBufferPosition() - rsaBlock1Start)));

	// GameOGLInformation (client feature, enabled since protocol 1061): two
	// filler bytes followed by GPU vendor/renderer and GL version, sent in
	// the clear (not part of either RSA block). Must be consumed here or
	// the second RSA block below would be read from the wrong offset.
	msg.skipBytes(2);
	msg.getString(); // GPU vendor + renderer
	msg.getString(); // GL version

	// GameAuthenticator (client feature, enabled since protocol 1072): a
	// second, separate RSA-encrypted block containing the TOTP token, sent
	// unconditionally by the client - empty when the player has no 2FA
	// token to provide. See Client/otclient-main/modules/gamelib/protocollogin.lua.
	// Protocol::RSA_decrypt() already validates and consumes the leading
	// zero byte internally (mirrors the first RSA block above, where the
	// XTEA key is read immediately after RSA_decrypt with no extra byte
	// skipped) - the token string starts right after it.
	std::string token;
	if (Protocol::RSA_decrypt(msg)) {
		token = msg.getString();
	}

	g_dispatcher().addEvent(
		[self = std::static_pointer_cast<ProtocolLogin>(shared_from_this()), accountDescriptor, password, token] {
			self->getCharacterList(accountDescriptor, password, token);
		},
		__FUNCTION__
	);
}

void ProtocolLogin::getLivestreamCharacterList(const std::string &password) const {
	const auto casters = g_livestream().getBroadcastingCasters(password);
	if (casters.empty()) {
		disconnectClient("There are no players with the livestream on.");
		return;
	}

	auto output = OutputMessagePool::getOutputMessage();
	output->addByte(0x14);
	output->addString("Welcome to Livestream System!");

	output->addByte(0x28);
	output->addString(fmt::format("@livestream\n{}", password));

	output->addByte(0x64);
	output->addByte(0x01); // worlds
	output->addByte(0x00);
	output->addString(g_configManager().getString(SERVER_NAME));
	output->addString(g_configManager().getString(IP));
	output->add<uint16_t>(g_configManager().getNumber(GAME_PORT));
	output->addByte(0x00);

	const auto casterCount = static_cast<uint8_t>(std::min<size_t>(std::numeric_limits<uint8_t>::max(), casters.size()));
	output->addByte(casterCount);
	for (size_t index = 0; index < casterCount; ++index) {
		const auto &caster = casters[index];
		output->addByte(0x00);
		output->addString(caster->getName());
	}

	output->addByte(0x00);
	output->addByte(0x00);
	output->add<uint32_t>(0x00);

	send(output);
	disconnect();
}
