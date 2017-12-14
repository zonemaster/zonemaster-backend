-- Initial setup for MySQL database
CREATE DATABASE zonemaster;
CREATE USER 'zonemaster'@'localhost' IDENTIFIED BY 'zonemaster';
CREATE USER 'zonemaster'@'%' IDENTIFIED BY 'zonemaster';

USE zonemaster;
CREATE TABLE test_results (
    id integer AUTO_INCREMENT PRIMARY KEY,
    hash_id VARCHAR(16) DEFAULT NULL,
    domain varchar(255) NOT NULL,
	batch_id integer NULL,
	creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
	test_start_time TIMESTAMP NULL,
	test_end_time TIMESTAMP NULL,
	priority integer DEFAULT 10,
	queue integer DEFAULT 0,
	progress integer DEFAULT 0,
	params_deterministic_hash character varying(32),
	params blob NOT NULL,
	results blob DEFAULT NULL,
    undelegated boolean NOT NULL DEFAULT false
) Engine=InnoDB;

CREATE INDEX test_results__hash_id ON test_results (hash_id);
CREATE INDEX test_results__params_deterministic_hash ON test_results (params_deterministic_hash);
CREATE INDEX test_results__batch_id_progress ON test_results (batch_id, progress);
CREATE INDEX test_results__progress ON test_results (progress);
CREATE INDEX test_results__domain_undelegated ON test_results (domain, undelegated);

DELIMITER //
CREATE TRIGGER before_insert_test_results
	BEFORE INSERT ON test_results
	FOR EACH ROW
	BEGIN
		IF new.hash_id IS NULL OR new.hash_id=''
		THEN
			SET new.hash_id = SUBSTRING(MD5(CONCAT(RAND(), UUID())) from 1 for 16);
		END IF;
	END//
DELIMITER //
			
CREATE TABLE batch_jobs (
    id integer AUTO_INCREMENT PRIMARY KEY,
    username character varying(50) NOT NULL,
    creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
) Engine=InnoDB;
CREATE TABLE users (
    id integer AUTO_INCREMENT primary key,
    username varchar(128),
    api_key varchar(512),
	user_info blob DEFAULT NULL
) Engine=InnoDB;
GRANT ALL ON zonemaster.test_results TO 'zonemaster';
GRANT LOCK TABLES          ON zonemaster.* TO 'zonemaster';
GRANT SELECT,UPDATE,INSERT ON zonemaster.batch_jobs TO 'zonemaster';
GRANT SELECT,UPDATE,INSERT ON zonemaster.users TO 'zonemaster';
