-- 共通データベースの作成
CREATE DATABASE IF NOT EXISTS `0_general` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE `0_general`;

-- テナントテーブル
CREATE TABLE IF NOT EXISTS `tenants` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(100) NOT NULL UNIQUE COMMENT 'テナントコード（例: acme, techcorp）',
  `name` VARCHAR(255) NOT NULL COMMENT 'テナント名',
  `db_name` VARCHAR(100) NOT NULL COMMENT 'データベース名',
  `active` BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'アクティブフラグ',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_code` (`code`),
  INDEX `idx_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ジョブ実行履歴テーブル
CREATE TABLE IF NOT EXISTS `job_execution_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(255) NOT NULL COMMENT 'ジョブ名',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'テナントID',
  `tenant_code` VARCHAR(100) NOT NULL COMMENT 'テナントコード',
  `status` VARCHAR(50) NOT NULL COMMENT '実行ステータス: success, failed, running',
  `started_at` TIMESTAMP NOT NULL COMMENT '開始時刻',
  `completed_at` TIMESTAMP NULL DEFAULT NULL COMMENT '完了時刻',
  `error_message` TEXT NULL COMMENT 'エラーメッセージ',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_job_name` (`job_name`),
  INDEX `idx_tenant_id` (`tenant_id`),
  INDEX `idx_tenant_code` (`tenant_code`),
  INDEX `idx_status` (`status`),
  INDEX `idx_started_at` (`started_at`),
  FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- テナントマスターデータの投入
INSERT INTO `tenants` (`id`, `code`, `name`, `db_name`, `active`) VALUES
  (1, 'acme', 'Acme Corporation', '1_acme', TRUE),
  (2, 'techcorp', 'Tech Corp', '2_techcorp', TRUE),
  (3, 'finserv', 'Financial Services Inc', '3_finserv', TRUE),
  (4, 'healthsys', 'Health Systems Ltd', '4_healthsys', TRUE),
  (5, 'edutech', 'Education Technology Group', '5_edutech', TRUE);
