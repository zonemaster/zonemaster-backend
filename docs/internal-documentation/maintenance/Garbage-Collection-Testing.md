# Testing instructions for the Garbage Collection feature of the Zonemaster Backend module

## Introduction
The purpose of this instruction is to serve as a notice for manual testing of the new garbage collection feature at release time.

## Testing the unfinished tests garbage collection feature


1. Start a test and wait for it to be finished

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

2. Simulate a crashed test
     ```
     UPDATE test_results SET progress = 50, test_start_time = '2020-01-01' WHERE hash_id = '3f7a604683efaf93';
     ```

3. Check that the backend finishes the test with a result stating it was unfinished

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

4. Ensure the test result contains the backend generated critical message:
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

