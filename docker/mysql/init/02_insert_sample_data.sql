-- サンプルデータを各テナントに挿入
USE `1_acme`;
INSERT INTO `sample_data` (`name`, `status`) VALUES
  ('Acme Product A', 'pending'),
  ('Acme Product B', 'completed'),
  ('Acme Product C', 'pending');

USE `2_techcorp`;
INSERT INTO `sample_data` (`name`, `status`) VALUES
  ('TechCorp Service X', 'pending'),
  ('TechCorp Service Y', 'completed'),
  ('TechCorp Service Z', 'failed');

USE `3_finserv`;
INSERT INTO `sample_data` (`name`, `status`) VALUES
  ('FinServ Transaction 001', 'completed'),
  ('FinServ Transaction 002', 'pending'),
  ('FinServ Transaction 003', 'pending');

USE `4_healthsys`;
INSERT INTO `sample_data` (`name`, `status`) VALUES
  ('HealthSys Patient Record 1', 'completed'),
  ('HealthSys Patient Record 2', 'pending');

USE `5_edutech`;
INSERT INTO `sample_data` (`name`, `status`) VALUES
  ('EduTech Course A', 'pending'),
  ('EduTech Course B', 'completed'),
  ('EduTech Course C', 'pending'),
  ('EduTech Course D', 'pending');
