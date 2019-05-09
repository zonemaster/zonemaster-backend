-- Initial setup of PostgreSQL database
CREATE USER zonemaster WITH PASSWORD 'zonemaster';
CREATE DATABASE zonemaster WITH ENCODING 'UTF8';

\c zonemaster

CREATE TABLE test_results (
    id serial primary key,
    hash_id VARCHAR(16) DEFAULT substring(md5(random()::text || clock_timestamp()::text) from 1 for 16) NOT NULL,
    batch_id integer,
	creation_time timestamp without time zone DEFAULT NOW() NOT NULL,
	test_start_time timestamp without time zone,
	test_end_time timestamp without time zone,
	priority integer DEFAULT 10,
	queue integer DEFAULT 0,
	progress integer DEFAULT 0,
	params_deterministic_hash varchar(32),
	params json NOT NULL,
	results json
);

CREATE INDEX test_results__hash_id ON test_results (hash_id);
CREATE INDEX test_results__params_deterministic_hash ON test_results (params_deterministic_hash);
CREATE INDEX test_results__batch_id_progress ON test_results (batch_id, progress);
CREATE INDEX test_results__progress ON test_results (progress);
CREATE INDEX test_results__domain_undelegated ON test_results ((params->>'domain'), (params->>'undelegated'));

CREATE TABLE batch_jobs (
    id serial PRIMARY KEY,
    username varchar(50) NOT NULL,
    creation_time timestamp without time zone NOT NULL DEFAULT NOW()
);

CREATE TABLE users (
    id serial PRIMARY KEY,
    user_info JSON
);

ALTER TABLE test_results OWNER TO zonemaster;
ALTER TABLE batch_jobs OWNER TO zonemaster;
ALTER TABLE users OWNER TO zonemaster;
GRANT USAGE ON test_results_id_seq, batch_jobs_id_seq, users_id_seq TO zonemaster;
