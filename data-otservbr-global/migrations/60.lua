function onUpdateDatabase()
	logger.info("Updating database to version 60 (add two-factor authentication columns to accounts)")

	local column = db.storeQuery("SHOW COLUMNS FROM `accounts` LIKE 'totp_secret';")
	if column then
		logger.warn("Column accounts.totp_secret already exists, skipping migration")
		Result.free(column)
		return true
	end

	if
		not db.query([[
		ALTER TABLE `accounts`
			ADD COLUMN `totp_secret` VARCHAR(64) NULL DEFAULT NULL,
			ADD COLUMN `totp_enabled` TINYINT(1) UNSIGNED NOT NULL DEFAULT '0';
	]])
	then
		logger.error("Failed to add two-factor authentication columns to accounts.")
		return false
	end

	return true
end
