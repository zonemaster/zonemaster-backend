-- Initial setup for MySQL database
CREATE DATABASE zonemaster;
CREATE USER 'zonemaster'@'localhost' IDENTIFIED BY 'zonemaster';
CREATE USER 'zonemaster'@'%' IDENTIFIED BY 'zonemaster';

USE zonemaster;
CREATE TABLE test_results (
    id integer AUTO_INCREMENT PRIMARY KEY,
    domain varchar(255) NOT NULL,
	batch_id integer NULL,
	creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
	test_start_time TIMESTAMP,
	test_end_time TIMESTAMP,
	priority integer DEFAULT 10,
	progress integer DEFAULT 0,
	params_deterministic_hash character varying(32),
	params blob NOT NULL,
	results blob DEFAULT NULL
) Engine=InnoDB;
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
GRANT SELECT,UPDATE,INSERT ON zonemaster.test_results TO 'zonemaster';
GRANT LOCK TABLES          ON zonemaster.* TO 'zonemaster';
GRANT SELECT,UPDATE,INSERT ON zonemaster.batch_jobs TO 'zonemaster';
GRANT SELECT,UPDATE,INSERT ON zonemaster.users TO 'zonemaster';
