-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Jul 09, 2026 at 06:45 PM
-- Server version: 11.4.12-MariaDB
-- PHP Version: 8.4.22

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `irankalc_dochub`
--
CREATE DATABASE IF NOT EXISTS `irankalc_dochub` DEFAULT CHARACTER SET latin1 COLLATE latin1_swedish_ci;
USE `irankalc_dochub`;

-- --------------------------------------------------------

--
-- Table structure for table `activity_log`
--

DROP TABLE IF EXISTS `activity_log`;
CREATE TABLE `activity_log` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `action` varchar(30) NOT NULL,
  `detail` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Truncate table before insert `activity_log`
--

TRUNCATE TABLE `activity_log`;
--
-- Dumping data for table `activity_log`
--

INSERT INTO `activity_log` (`id`, `user_id`, `action`, `detail`, `created_at`) VALUES
(1, 1, 'login', '', '2026-07-06 23:03:59'),
(2, 1, 'logout', '', '2026-07-06 23:13:39'),
(3, 1, 'login', '', '2026-07-06 23:14:31'),
(4, 1, 'logout', '', '2026-07-06 23:15:14'),
(5, 2, 'login', '', '2026-07-06 23:15:46'),
(6, 1, 'login', '', '2026-07-07 00:06:32'),
(7, 1, 'upload', 'Kari Panchadcharam.docx', '2026-07-07 00:07:16'),
(8, 1, 'download', 'Kari Panchadcharam.docx', '2026-07-07 00:07:30'),
(9, 1, 'download', 'Kari Panchadcharam.docx', '2026-07-07 00:07:59'),
(10, 1, 'download', 'Kari Panchadcharam.docx', '2026-07-07 00:08:01'),
(11, 1, 'delete', 'Kari Panchadcharam.docx', '2026-07-07 00:08:10'),
(12, 1, 'upload', 'Kari Panchadcharam.docx', '2026-07-07 00:18:01'),
(13, 1, 'download', 'Kari Panchadcharam.docx', '2026-07-07 00:18:16'),
(14, 1, 'upload_version', 'Kari Panchadcharam.docx', '2026-07-07 00:18:36'),
(15, 1, 'download', 'Kari Panchadcharam.docx', '2026-07-07 00:19:51'),
(16, 1, 'logout', '', '2026-07-07 00:19:54'),
(17, 1, 'login', '', '2026-07-07 00:22:08'),
(18, 1, 'download', 'Kari Panchadcharam.docx', '2026-07-07 00:22:28'),
(19, 1, 'upload', 'IMG_1538.jpeg', '2026-07-07 00:25:44'),
(20, 1, 'download', 'IMG_1538.jpeg', '2026-07-07 00:25:50'),
(21, 1, 'folder_restrict', 'Board documents → restricted', '2026-07-07 00:28:27'),
(22, 1, 'view', 'Kari Panchadcharam.docx', '2026-07-07 00:39:36'),
(23, 1, 'download', 'Kari Panchadcharam.docx', '2026-07-07 00:39:36'),
(24, 1, 'view', 'IMG_1538.jpeg', '2026-07-07 00:39:52'),
(25, 1, 'download', 'IMG_1538.jpeg', '2026-07-07 00:39:52'),
(26, 1, 'upload', 'fcs-programs-test.csv', '2026-07-07 00:41:17'),
(27, 1, 'view', 'fcs-programs-test.csv', '2026-07-07 00:41:22'),
(28, 1, 'download', 'fcs-programs-test.csv', '2026-07-07 00:41:22'),
(29, 1, 'edit', 'fcs-programs-test.csv', '2026-07-07 00:41:34'),
(30, 1, 'view', 'fcs-programs-test.csv', '2026-07-07 00:41:34'),
(31, 1, 'download', 'fcs-programs-test.csv', '2026-07-07 00:41:34'),
(32, 1, 'view', 'fcs-programs-test.csv', '2026-07-07 00:52:48'),
(33, 1, 'download', 'fcs-programs-test.csv', '2026-07-07 00:52:48'),
(34, 1, 'view', 'Kari Panchadcharam.docx', '2026-07-07 00:53:58'),
(35, 1, 'download', 'Kari Panchadcharam.docx', '2026-07-07 00:53:58'),
(36, 1, 'download', 'Kari Panchadcharam.docx', '2026-07-07 00:54:00'),
(37, 1, 'view', 'Kari Panchadcharam.docx', '2026-07-07 00:54:24'),
(38, 1, 'download', 'Kari Panchadcharam.docx', '2026-07-07 00:54:24'),
(39, 1, 'view', 'fcs-programs-test.csv', '2026-07-07 00:54:41'),
(40, 1, 'download', 'fcs-programs-test.csv', '2026-07-07 00:54:42'),
(41, 1, 'logout', '', '2026-07-07 00:55:50'),
(42, 3, 'login', '', '2026-07-07 00:56:47'),
(43, 3, 'view', 'fcs-programs-test.csv', '2026-07-07 00:56:54'),
(44, 3, 'download', 'fcs-programs-test.csv', '2026-07-07 00:56:54'),
(45, 3, 'view', 'Kari Panchadcharam.docx', '2026-07-07 00:57:15'),
(46, 3, 'download', 'Kari Panchadcharam.docx', '2026-07-07 00:57:16'),
(47, 3, 'download', 'Kari Panchadcharam.docx', '2026-07-07 00:57:17'),
(48, 3, 'view', 'fcs-programs-test.csv', '2026-07-07 00:57:26'),
(49, 3, 'download', 'fcs-programs-test.csv', '2026-07-07 00:57:26'),
(50, 3, 'view', 'IMG_1538.jpeg', '2026-07-07 00:57:59'),
(51, 3, 'download', 'IMG_1538.jpeg', '2026-07-07 00:57:59'),
(52, 3, 'logout', '', '2026-07-07 01:00:29'),
(53, 1, 'login', '', '2026-07-07 12:21:18'),
(54, 1, 'login', '', '2026-07-07 12:37:52'),
(55, 1, 'view', 'fcs-programs-test.csv', '2026-07-07 12:39:14'),
(56, 1, 'download', 'fcs-programs-test.csv', '2026-07-07 12:39:14'),
(57, 1, 'view', 'fcs-programs-test.csv', '2026-07-07 12:39:26'),
(58, 1, 'download', 'fcs-programs-test.csv', '2026-07-07 12:39:26'),
(59, 1, 'login', '', '2026-07-07 12:48:50'),
(60, 1, 'folder_restrict', 'Policies → restricted', '2026-07-07 13:00:21'),
(61, 1, 'login', '', '2026-07-09 13:57:53'),
(62, 1, 'delete', 'fcs-programs-test.csv', '2026-07-09 13:58:53'),
(63, 1, 'view', 'Kari Panchadcharam.docx', '2026-07-09 13:58:54'),
(64, 1, 'download', 'Kari Panchadcharam.docx', '2026-07-09 13:58:55'),
(65, 1, 'view', 'Kari Panchadcharam.docx', '2026-07-09 13:59:07'),
(66, 1, 'download', 'Kari Panchadcharam.docx', '2026-07-09 13:59:07'),
(67, 1, 'view', 'IMG_1538.jpeg', '2026-07-09 13:59:46'),
(68, 1, 'download', 'IMG_1538.jpeg', '2026-07-09 13:59:46'),
(69, 1, 'delete', 'IMG_1538.jpeg', '2026-07-09 13:59:57'),
(70, 1, 'delete', 'Kari Panchadcharam.docx', '2026-07-09 14:00:21'),
(71, 1, 'user_add', 'alyssa.boffo@fcsgw.org (admin)', '2026-07-09 14:02:28'),
(72, 1, 'logout', '', '2026-07-09 14:11:26'),
(73, 4, 'login', '', '2026-07-09 14:11:46');

-- --------------------------------------------------------

--
-- Table structure for table `documents`
--

DROP TABLE IF EXISTS `documents`;
CREATE TABLE `documents` (
  `id` int(10) UNSIGNED NOT NULL,
  `folder_id` int(10) UNSIGNED NOT NULL,
  `display_name` varchar(255) NOT NULL,
  `stored_name` varchar(64) NOT NULL,
  `mime_type` varchar(120) NOT NULL,
  `file_ext` varchar(10) NOT NULL,
  `size_bytes` bigint(20) UNSIGNED NOT NULL,
  `uploaded_by` int(10) UNSIGNED NOT NULL,
  `uploaded_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Truncate table before insert `documents`
--

TRUNCATE TABLE `documents`;
-- --------------------------------------------------------

--
-- Table structure for table `document_versions`
--

DROP TABLE IF EXISTS `document_versions`;
CREATE TABLE `document_versions` (
  `id` int(10) UNSIGNED NOT NULL,
  `document_id` int(10) UNSIGNED NOT NULL,
  `stored_name` varchar(64) NOT NULL,
  `mime_type` varchar(120) NOT NULL,
  `file_ext` varchar(10) NOT NULL,
  `size_bytes` bigint(20) UNSIGNED NOT NULL,
  `uploaded_by` int(10) UNSIGNED NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Truncate table before insert `document_versions`
--

TRUNCATE TABLE `document_versions`;
-- --------------------------------------------------------

--
-- Table structure for table `folders`
--

DROP TABLE IF EXISTS `folders`;
CREATE TABLE `folders` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(120) NOT NULL,
  `sort_order` int(11) NOT NULL DEFAULT 0,
  `restricted` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Truncate table before insert `folders`
--

TRUNCATE TABLE `folders`;
--
-- Dumping data for table `folders`
--

INSERT INTO `folders` (`id`, `name`, `sort_order`, `restricted`) VALUES
(1, 'Policies', 1, 1),
(2, 'Forms', 2, 0),
(3, 'HR', 3, 0),
(4, 'Board documents', 4, 1),
(5, 'Images', 5, 0);

-- --------------------------------------------------------

--
-- Table structure for table `folder_permissions`
--

DROP TABLE IF EXISTS `folder_permissions`;
CREATE TABLE `folder_permissions` (
  `folder_id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `can_edit` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Truncate table before insert `folder_permissions`
--

TRUNCATE TABLE `folder_permissions`;
-- --------------------------------------------------------

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id` int(10) UNSIGNED NOT NULL,
  `email` varchar(190) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `full_name` varchar(120) NOT NULL,
  `role` enum('admin','editor','viewer') NOT NULL DEFAULT 'viewer',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `last_login` timestamp NULL DEFAULT NULL,
  `notify_uploads` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Truncate table before insert `users`
--

TRUNCATE TABLE `users`;
--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `email`, `password_hash`, `full_name`, `role`, `is_active`, `created_at`, `last_login`, `notify_uploads`) VALUES
(1, 'admin@fcsgw.org', '$2y$12$PFbKTafelDOpZB/AN56lNOiRWCOeTI6MSM7NJ7lG1602LB5gLTIAC', 'System Administrator', 'admin', 1, '2026-07-06 23:02:36', '2026-07-09 13:57:53', 0),
(2, 'editor@fcsgw.org', '$2y$12$PFbKTafelDOpZB/AN56lNOiRWCOeTI6MSM7NJ7lG1602LB5gLTIAC', 'Sample Editor', 'editor', 1, '2026-07-06 23:02:36', '2026-07-06 23:15:46', 0),
(3, 'viewer@fcsgw.org', '$2y$12$PFbKTafelDOpZB/AN56lNOiRWCOeTI6MSM7NJ7lG1602LB5gLTIAC', 'Sample Viewer', 'viewer', 1, '2026-07-06 23:02:36', '2026-07-07 00:56:47', 0),
(4, 'alyssa.boffo@fcsgw.org', '$2y$12$gRDyNE14E7GxXg7KtHX47uuCbxkYjV66gf9n5oRM3WPL/tNEsfkoW', 'Alyssa Boffo', 'admin', 1, '2026-07-09 14:02:28', '2026-07-09 14:11:46', 0);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `activity_log`
--
ALTER TABLE `activity_log`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_time` (`user_id`,`created_at`);

--
-- Indexes for table `documents`
--
ALTER TABLE `documents`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `stored_name` (`stored_name`),
  ADD KEY `uploaded_by` (`uploaded_by`),
  ADD KEY `idx_folder` (`folder_id`),
  ADD KEY `idx_name` (`display_name`);

--
-- Indexes for table `document_versions`
--
ALTER TABLE `document_versions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `stored_name` (`stored_name`),
  ADD KEY `uploaded_by` (`uploaded_by`),
  ADD KEY `idx_doc` (`document_id`);

--
-- Indexes for table `folders`
--
ALTER TABLE `folders`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `name` (`name`);

--
-- Indexes for table `folder_permissions`
--
ALTER TABLE `folder_permissions`
  ADD PRIMARY KEY (`folder_id`,`user_id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `activity_log`
--
ALTER TABLE `activity_log`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=74;

--
-- AUTO_INCREMENT for table `documents`
--
ALTER TABLE `documents`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `document_versions`
--
ALTER TABLE `document_versions`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `folders`
--
ALTER TABLE `folders`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `activity_log`
--
ALTER TABLE `activity_log`
  ADD CONSTRAINT `activity_log_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`);

--
-- Constraints for table `documents`
--
ALTER TABLE `documents`
  ADD CONSTRAINT `documents_ibfk_1` FOREIGN KEY (`folder_id`) REFERENCES `folders` (`id`),
  ADD CONSTRAINT `documents_ibfk_2` FOREIGN KEY (`uploaded_by`) REFERENCES `users` (`id`);

--
-- Constraints for table `document_versions`
--
ALTER TABLE `document_versions`
  ADD CONSTRAINT `document_versions_ibfk_1` FOREIGN KEY (`document_id`) REFERENCES `documents` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `document_versions_ibfk_2` FOREIGN KEY (`uploaded_by`) REFERENCES `users` (`id`);

--
-- Constraints for table `folder_permissions`
--
ALTER TABLE `folder_permissions`
  ADD CONSTRAINT `folder_permissions_ibfk_1` FOREIGN KEY (`folder_id`) REFERENCES `folders` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `folder_permissions_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
