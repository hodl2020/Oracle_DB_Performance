--Finding top 10 potential performance bottleneck across instances 
--in case of non-RAC environment just use v$ views
SELECT *
  FROM (
		SELECT   inst_id,session_id,session_serial#,COUNT(*) 
		FROM     gv$active_session_history
		GROUP BY inst_id,session_id,session_serial# 
		ORDER BY COUNT(*) desc
		)
 WHERE ROWNUM <= 10;

--Now that we get hold of top sessions so we can dig further
--Also useful in case performance bottleneck is already known
-- &v_ argument represent sessions we are probing or those found in earlier query

--Find top sqls and corresponding events for a specific session
SELECT   sql_id , event , COUNT(*) 
FROM     gv$active_session_history 
WHERE    session_id = &v_session_id 
AND 	 session_serial# = &v_session_serial
AND 	 inst_id = &v_inst_id	
GROUP BY sql_id , event 
ORDER BY COUNT(*) desc;

-- Find top events for a specific sql (sql id obtained from previous query)
SELECT   event , COUNT(*) 
FROM     gv$active_session_history 
WHERE    sql_id = &v_sql_id
GROUP BY sql_id , event 
ORDER BY COUNT(*) desc;

--Find Most accessed objects for a sql(sql id obtained from previous query)

SELECT 	 current_obj#,COUNT(*) 
FROM 	 gv$active_session_history 
WHERE 	 sql_id = &v_sql_id
GROUP BY current_obj# 
ORDER BY COUNT(*) desc;

--get details FROM dba_objects
SELECT object_name , subobject_name , object_type
FROM   dba_objects d
WHERE  d.object_id = &current_obj;

-- Find out whether you session was reading FROM undo or not
--step 1, get dbid
SELECT dbid FROM v$database;

--step 2, get snaps
SELECT MAX (snap_id), MIN (snap_id)
  FROM SYS.wrm$_snapshot
 WHERE CAST (begin_interval_time AS DATE) BETWEEN TO_DATE
                                                    ('01/04/2019 00:00:00',
                                                     'dd/mm/yyyy hh24:mi:ss'
                                                    )     -- Change these as per scenario
                                              AND TO_DATE
                                                    ('01/04/2019 23:59:59',
                                                     'dd/mm/yyyy hh24:mi:ss'
                                                    )     -- Change these as per scenario
;                            

--step 3
--use dbid and snapids found earlier
--We use dba_hist instead dynamic performance view cause we need dig further in history in case query performance degraded due to undo reads 
SELECT event,f.tablespace_name,COUNT(*)
FROM   dba_hist_active_sess_history   ,dba_data_files f 
WHERE  dbid = &v_dbid
AND    snap_id BETWEEN &v_min_snap and &v_max_snap
AND    session_id = &v_session_id AND session_serial#=&v_session_serial
--AND sql_id = &v_sql_id
AND    f.file_id = p1
GROUP BY event,tablespace_name
ORDER BY COUNT(*) DESC;


--You can get blocking sessions

SELECT blocking_session,blocking_session_serial# 
FROM   gv$active_session_history 
WHERE  session_id = &v_session_id AND session_serial#=&v_session_serial;


--Last but not least 
--Generate ASH report quick
--Use previous dbid,snap and Spool result,save it in html format  
SELECT * FROM TABLE(DBMS_WORKLOAD_REPOSITORY.ASH_REPORT_HTML(&dbid, &inst_id, TO_DATE('&startdate', 'YYYY-MM-DD HH24:MI'), TO_DATE('&enddate', 'YYYY-MM-DD HH24:MI'), null, null, null, null ));