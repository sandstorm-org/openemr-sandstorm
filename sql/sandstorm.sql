DROP TABLE IF EXISTS `sandstorm_users`;
CREATE TABLE `sandstorm_users` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) NOT NULL COMMENT 'references users.id',
  `sandstorm_user_id` binary(16) NOT NULL COMMENT 'X-Sandstorm-User-Id header',
  PRIMARY KEY (`id`),
  CONSTRAINT FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
