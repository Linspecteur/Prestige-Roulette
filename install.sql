CREATE TABLE IF NOT EXISTS `roulette_players` (
    `identifier` VARCHAR(60) NOT NULL PRIMARY KEY,
    `spins` INT DEFAULT 0,
    `money_spent` INT DEFAULT 0,
    `money_won` INT DEFAULT 0,
    `weapons_won` INT DEFAULT 0,
    `vehicles_won` INT DEFAULT 0,
    `free_spins` INT DEFAULT 0,
    `used_codes` LONGTEXT DEFAULT '[]'
);

CREATE TABLE IF NOT EXISTS `roulette_inventory` (
    `id` VARCHAR(50) NOT NULL PRIMARY KEY,
    `identifier` VARCHAR(60) NOT NULL,
    `label` VARCHAR(255) NOT NULL,
    `value` VARCHAR(255) NOT NULL,
    `type` VARCHAR(50) NOT NULL,
    `quantity` INT DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `roulette_global` (
    `name` VARCHAR(50) NOT NULL PRIMARY KEY,
    `value` INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS `roulette_winners` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL,
    `reward` VARCHAR(255) NOT NULL,
    `type` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
