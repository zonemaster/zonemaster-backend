-- Initial setup of PostgreSQL database
CREATE USER zonemaster WITH PASSWORD 'zonemaster';
CREATE DATABASE zonemaster WITH ENCODING 'UTF8';
GRANT ALL ON zonemaster.* TO 'zonemaster'@'localhost';
