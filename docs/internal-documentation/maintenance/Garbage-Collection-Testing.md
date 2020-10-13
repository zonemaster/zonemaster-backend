# Testing instructions for the Garbage Collection feature of the Zonemaster Backend module

## Introduction
The purpose of this instruction is to serve as a notice for manual testing of the new garbage collection feature at release time.

## Testing the unfinished tests garbage collection feature

1. Ensure that the database has the required additionnal columns for this feature:
     ```
     SELECT nb_retries FROM test_results LIMIT 0;
     ```
     Should return:

     ```
     nb_retries 
     ------------
     (0 rows)
     ```
     _Remark: for MySQL use `SHOW COLUMNS FROM test_results` and ensure the `nb_retries` column is present in the list._

2. Check that your `/etc/zonemaster/backend_config.ini` (or, in FreeBSD, `/usr/local/etc/zonemaster/backend_config.ini`) has the proper parameter set

     Either disabled:
     ```
     #maximal_number_of_retries=3
     ```
     or set to 0:
     ```
     maximal_number_of_retries=0
     ```

3. Start a test and wait for it to be finished

     ```
     SELECT hash_id, progress FROM test_results LIMIT 1;
     ```
     Should return:

     ```
          hash_id      | progress 
     ------------------+----------
     3f7a604683efaf93 |      100
     (1 row)
     ```

4. Simulate a crashed test
     ```
     UPDATE test_results SET progress = 50, test_start_time = '2020-01-01' WHERE hash_id = '3f7a604683efaf93';
     ```

5. Check that the backend finishes the test with a result stating it was unfinished

     ```
     SELECT hash_id, progress FROM test_results WHERE hash_id = '3f7a604683efaf93';
     ```
     Should return a finished result:
     ```
          hash_id      | progress 
     ------------------+----------
     3f7a604683efaf93 |      100
     (1 row)
     ```

6. Ensure the test result contains the backend generated critical message:
     ```
     {"tag":"UNABLE_TO_FINISH_TEST","level":"CRITICAL","timestamp":"300","module":"BACKEND_TEST_AGENT"}
     ```

     ```
     SELECT hash_id, progress FROM test_results WHERE hash_id = '3f7a604683efaf93' AND results::text like '%UNABLE_TO_FINISH_TEST%';
     ```
     _Remark: for MySQL queries remove the `::text` from all queries_

     Should return:
     ```
          hash_id      | progress 
     ------------------+----------
     3f7a604683efaf93 |      100
     (1 row)

     ```

## Testing the unfinished tests garbage collection feature with a number of retries set to allow finishing tests without a critical error

1. Set the maximal_number_of_retries parameter to a value greater than 0 in the backend_config.ini config file 
     ```
     maximal_number_of_retries=1
     ```

2. Restart the test agent in order for the parameter to be taken into account
     ```
     zonemaster_backend_testagent restart
     ```
     _Remark: Update accordingly to the OS where the tests are done (ex use init script for FreeBSD, etc.)_

3. Simulate a crashed test
     ```
     UPDATE test_results SET progress = 50, test_start_time = '2020-01-01' WHERE hash_id = '3f7a604683efaf93';
     ```

4. Check that the backend finishes the test WITHOUT a result stating it was unfinished

     ```
     SELECT hash_id, progress FROM test_results WHERE hash_id = '3f7a604683efaf93';
     ```
     Should return a finished result:
     ```
          hash_id      | progress 
     ------------------+----------
     3f7a604683efaf93 |      100
     (1 row)
     ```

5. Ensure the test result does NOT contain the backend generated critical message:
     ```
     {"tag":"UNABLE_TO_FINISH_TEST","level":"CRITICAL","timestamp":"300","module":"BACKEND_TEST_AGENT"}
     ```

     ```
     SELECT hash_id, progress FROM test_results WHERE hash_id = '3f7a604683efaf93' AND results::text like '%UNABLE_TO_FINISH_TEST%';
     ```
     _Remark: for MySQL queries remove the `::text` from all queries_
     Should return:
     ```
     hash_id | progress 
     ---------+----------
     (0 rows)

     ```
