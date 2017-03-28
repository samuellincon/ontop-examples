CREATE TEMPORARY TABLE DIAMOND_CU4800_1 AS
WITH C0_CU4800_1 AS (
SELECT * FROM tb_sensor_unified WHERE maxrotorspeed IS NOT NULL
),

C1_CU4800_1 AS (
SELECT dFrom, dTo
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
maxrotorspeed AS currRs,
LEAD(maxrotorspeed, 1) OVER (ORDER BY  datetime) AS nextRs
FROM C0_CU4800_1) F
WHERE currRs <= 4400 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'
),

C2_CU4800_1 (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_CU4800_1 
UNION ALL
SELECT 0, 1, dTo
FROM C1_CU4800_1  
),

C3_CU4800_1 AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_CU4800_1
),

C4_CU4800_1 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_CU4800_1
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
),

BOX_CU4800_1 AS (
SELECT (prevTs + interval '30 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_CU4800_1) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '30 seconds')

SELECT (dFrom + interval '10 seconds') AS dFrom, (dTo + interval '2 minutes 10') AS dTo FROM BOX_CU4800_1;

CREATE TEMPORARY TABLE BOX_CU4800_2 AS 

WITH C0_CU4800_2 AS (
SELECT * FROM tb_sensor_unified WHERE maxrotorspeed IS NOT NULL
),

C1_CU4800_2 AS (
SELECT dFrom, dTo
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
maxrotorspeed AS currRs,
LEAD(maxrotorspeed, 1) OVER (ORDER BY  datetime) AS nextRs
FROM C0_CU4800_2) F
WHERE currRs >= 4800 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'
),

C2_CU4800_2 (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_CU4800_2 
UNION ALL
SELECT 0, 1, dTo
FROM C1_CU4800_2  
),

C3_CU4800_2 AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_CU4800_2
),

C4_CU4800_2 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_CU4800_2
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
)

SELECT (prevTs + interval '10 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_CU4800_2) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '10 seconds';

CREATE INDEX DIAMOND_CU4800_1_IDX_FROM_TO ON DIAMOND_CU4800_1 (dFrom,dTo);
CREATE INDEX BOX_CU4800_2_IDX_FROM_TO ON BOX_CU4800_2 (dFrom,dTo);

CREATE TEMPORARY TABLE DIAMOND_CU4800 AS
WITH CU4800 AS (
SELECT
CASE 
WHEN DIAMOND_CU4800_1.dFrom > BOX_CU4800_2.dFrom AND BOX_CU4800_2.dTo > DIAMOND_CU4800_1.dFrom THEN DIAMOND_CU4800_1.dFrom
WHEN BOX_CU4800_2.dFrom > DIAMOND_CU4800_1.dFrom AND DIAMOND_CU4800_1.dTo > BOX_CU4800_2.dFrom THEN BOX_CU4800_2.dFrom
WHEN DIAMOND_CU4800_1.dFrom = BOX_CU4800_2.dFrom THEN DIAMOND_CU4800_1.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_CU4800_1.dTo < BOX_CU4800_2.dTo AND DIAMOND_CU4800_1.dTo > BOX_CU4800_2.dFrom THEN DIAMOND_CU4800_1.dTo
WHEN BOX_CU4800_2.dTo < DIAMOND_CU4800_1.dTo AND BOX_CU4800_2.dTo > DIAMOND_CU4800_1.dFrom THEN BOX_CU4800_2.dTo
WHEN DIAMOND_CU4800_1.dTo = BOX_CU4800_2.dTo THEN DIAMOND_CU4800_1.dTo
END AS dTo
FROM DIAMOND_CU4800_1, BOX_CU4800_2
WHERE
((DIAMOND_CU4800_1.dFrom > BOX_CU4800_2.dFrom AND BOX_CU4800_2.dTo > DIAMOND_CU4800_1.dFrom) OR (BOX_CU4800_2.dFrom > DIAMOND_CU4800_1.dFrom AND DIAMOND_CU4800_1.dTo > BOX_CU4800_2.dFrom) OR (DIAMOND_CU4800_1.dFrom = BOX_CU4800_2.dFrom)) AND
((DIAMOND_CU4800_1.dTo < BOX_CU4800_2.dTo AND DIAMOND_CU4800_1.dTo > BOX_CU4800_2.dFrom) OR (BOX_CU4800_2.dTo < DIAMOND_CU4800_1.dTo AND BOX_CU4800_2.dTo > DIAMOND_CU4800_1.dFrom) OR (DIAMOND_CU4800_1.dTo = BOX_CU4800_2.dTo)))

SELECT (dFrom - interval '30 seconds') as dFrom, dTo FROM CU4800;

CREATE TEMPORARY TABLE DIAMOND_CU4400_1 AS
WITH C0_CU4400_1 AS (
SELECT * FROM tb_sensor_unified WHERE maxrotorspeed IS NOT NULL
),

C1_CU4400_1 AS (
SELECT dFrom, dTo
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
maxrotorspeed AS currRs,
LEAD(maxrotorspeed, 1) OVER (ORDER BY  datetime) AS nextRs
FROM C0_CU4400_1) F
WHERE currRs <= 1500 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'
),

C2_CU4400_1 (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_CU4400_1
UNION ALL
SELECT 0, 1, dTo
FROM C1_CU4400_1
),

C3_CU4400_1 AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_CU4400_1
),

C4_CU4400_1 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_CU4400_1
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
),

BOX_CU4400_1 AS (
SELECT (prevTs + interval '30 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_CU4400_1) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '30 seconds')

SELECT (dFrom + interval '30 seconds') AS dFrom, (dTo + interval '7 minutes') AS dTo FROM BOX_CU4400_1;

CREATE TEMPORARY TABLE BOX_CU4400_2 AS

WITH C0_CU4400_2 AS (
SELECT * FROM tb_sensor_unified WHERE maxrotorspeed IS NOT NULL
),

C1_CU4400_2 AS (
SELECT dFrom, dTo
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
maxrotorspeed AS currRs,
LEAD(maxrotorspeed, 1) OVER (ORDER BY  datetime) AS nextRs
FROM C0_CU4400_2) F
WHERE currRs >= 4400 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'
),

C2_CU4400_2 (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_CU4400_2
UNION ALL
SELECT 0, 1, dTo
FROM C1_CU4400_2
),

C3_CU4400_2 AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_CU4400_2
),

C4_CU4400_2 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_CU4400_2
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
)

SELECT (prevTs + interval '30 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_CU4400_2) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '30 seconds';

CREATE INDEX DIAMOND_CU4800_IDX_FROM_TO ON DIAMOND_CU4800 (dFrom,dTo);
CREATE INDEX DIAMOND_CU4400_1_IDX_FROM_TO ON DIAMOND_CU4400_1 (dFrom,dTo);
CREATE INDEX BOX_CU4400_2_IDX_FROM_TO ON BOX_CU4400_2 (dFrom,dTo);

CREATE TEMPORARY TABLE CU4400 AS 
SELECT
CASE 
WHEN DIAMOND_CU4400_1.dFrom > BOX_CU4400_2.dFrom AND BOX_CU4400_2.dTo > DIAMOND_CU4400_1.dFrom THEN DIAMOND_CU4400_1.dFrom
WHEN BOX_CU4400_2.dFrom > DIAMOND_CU4400_1.dFrom AND DIAMOND_CU4400_1.dTo > BOX_CU4400_2.dFrom THEN BOX_CU4400_2.dFrom
WHEN DIAMOND_CU4400_1.dFrom = BOX_CU4400_2.dFrom THEN DIAMOND_CU4400_1.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_CU4400_1.dTo < BOX_CU4400_2.dTo AND DIAMOND_CU4400_1.dTo > BOX_CU4400_2.dFrom THEN DIAMOND_CU4400_1.dTo
WHEN BOX_CU4400_2.dTo < DIAMOND_CU4400_1.dTo AND BOX_CU4400_2.dTo > DIAMOND_CU4400_1.dFrom THEN BOX_CU4400_2.dTo
WHEN DIAMOND_CU4400_1.dTo = BOX_CU4400_2.dTo THEN DIAMOND_CU4400_1.dTo
END AS dTo
FROM DIAMOND_CU4400_1, BOX_CU4400_2
WHERE
((DIAMOND_CU4400_1.dFrom > BOX_CU4400_2.dFrom AND BOX_CU4400_2.dTo > DIAMOND_CU4400_1.dFrom) OR (BOX_CU4400_2.dFrom > DIAMOND_CU4400_1.dFrom AND DIAMOND_CU4400_1.dTo > BOX_CU4400_2.dFrom) OR (DIAMOND_CU4400_1.dFrom = BOX_CU4400_2.dFrom)) AND
((DIAMOND_CU4400_1.dTo < BOX_CU4400_2.dTo AND DIAMOND_CU4400_1.dTo > BOX_CU4400_2.dFrom) OR (BOX_CU4400_2.dTo < DIAMOND_CU4400_1.dTo AND BOX_CU4400_2.dTo > DIAMOND_CU4400_1.dFrom) OR (DIAMOND_CU4400_1.dTo = BOX_CU4400_2.dTo));

CREATE TEMPORARY TABLE DIAMOND_D AS
WITH D AS (
SELECT
CASE 
WHEN DIAMOND_CU4800.dFrom > CU4400.dFrom AND CU4400.dTo > DIAMOND_CU4800.dFrom THEN DIAMOND_CU4800.dFrom
WHEN CU4400.dFrom > DIAMOND_CU4800.dFrom AND DIAMOND_CU4800.dTo > CU4400.dFrom THEN CU4400.dFrom
WHEN DIAMOND_CU4800.dFrom = CU4400.dFrom THEN DIAMOND_CU4800.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_CU4800.dTo < CU4400.dTo AND DIAMOND_CU4800.dTo > CU4400.dFrom THEN DIAMOND_CU4800.dTo
WHEN CU4400.dTo < DIAMOND_CU4800.dTo AND CU4400.dTo > DIAMOND_CU4800.dFrom THEN CU4400.dTo
WHEN DIAMOND_CU4800.dTo = CU4400.dTo THEN DIAMOND_CU4800.dTo
END AS dTo
FROM DIAMOND_CU4800, CU4400
WHERE
((DIAMOND_CU4800.dFrom > CU4400.dFrom AND CU4400.dTo > DIAMOND_CU4800.dFrom) OR (CU4400.dFrom > DIAMOND_CU4800.dFrom AND DIAMOND_CU4800.dTo > CU4400.dFrom) OR (DIAMOND_CU4800.dFrom = CU4400.dFrom)) AND
((DIAMOND_CU4800.dTo < CU4400.dTo AND DIAMOND_CU4800.dTo > CU4400.dFrom) OR (CU4400.dTo < DIAMOND_CU4800.dTo AND CU4400.dTo > DIAMOND_CU4800.dFrom) OR (DIAMOND_CU4800.dTo = CU4400.dTo)))

SELECT (dFrom - interval '5 minutes') AS dFrom, dTo From D;

CREATE TEMPORARY TABLE DIAMOND_CU1000_1 AS

WITH C0_CU1000_1 AS (
SELECT * FROM tb_sensor_unified WHERE maxrotorspeed IS NOT NULL
),

C1_CU1000_1 AS (
SELECT dFrom, dTo
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
maxrotorspeed AS currRs,
LEAD(maxrotorspeed, 1) OVER (ORDER BY  datetime) AS nextRs
FROM C0_CU1000_1) F
WHERE currRs <= 1000 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'
),

C2_CU1000_1 (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_CU1000_1
UNION ALL
SELECT 0, 1, dTo
FROM C1_CU1000_1
),

C3_CU1000_1 AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_CU1000_1
),

C4_CU1000_1 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_CU1000_1
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
),

BOX_CU1000_1 AS (
SELECT (prevTs + interval '60 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_CU1000_1) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '60 seconds')

SELECT (dFrom + interval '0 seconds') AS dFrom, (dTo + interval '2 minutes') AS dTo FROM BOX_CU1000_1;

CREATE TEMPORARY TABLE BOX_CU1000_2 AS
WITH C0_CU1000_2 AS (
SELECT * FROM tb_sensor_unified WHERE maxrotorspeed IS NOT NULL
),

C1_CU1000_2 AS (
SELECT dFrom, dTo
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
maxrotorspeed AS currRs,
LEAD(maxrotorspeed, 1) OVER (ORDER BY  datetime) AS nextRs
FROM C0_CU1000_2) F
WHERE currRs >= 1260 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'
),

C2_CU1000_2 (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_CU1000_2
UNION ALL
SELECT 0, 1, dTo
FROM C1_CU1000_2
),

C3_CU1000_2 AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_CU1000_2
),

C4_CU1000_2 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_CU1000_2
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
)

SELECT (prevTs + interval '30 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_CU1000_2) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '30 seconds';

CREATE INDEX DIAMOND_CU1000_1_IDX_FROM_TO ON DIAMOND_CU1000_1 (dFrom, dTo);
CREATE INDEX BOX_CU1000_2_IDX_FROM_TO ON BOX_CU1000_2 (dFrom,dTo);


CREATE TEMPORARY TABLE DIAMOND_E AS
WITH E AS (
SELECT
CASE 
WHEN DIAMOND_CU1000_1.dFrom > BOX_CU1000_2.dFrom AND BOX_CU1000_2.dTo > DIAMOND_CU1000_1.dFrom THEN DIAMOND_CU1000_1.dFrom
WHEN BOX_CU1000_2.dFrom > DIAMOND_CU1000_1.dFrom AND DIAMOND_CU1000_1.dTo > BOX_CU1000_2.dFrom THEN BOX_CU1000_2.dFrom
WHEN DIAMOND_CU1000_1.dFrom = BOX_CU1000_2.dFrom THEN DIAMOND_CU1000_1.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_CU1000_1.dTo < BOX_CU1000_2.dTo AND DIAMOND_CU1000_1.dTo > BOX_CU1000_2.dFrom THEN DIAMOND_CU1000_1.dTo
WHEN BOX_CU1000_2.dTo < DIAMOND_CU1000_1.dTo AND BOX_CU1000_2.dTo > DIAMOND_CU1000_1.dFrom THEN BOX_CU1000_2.dTo
WHEN DIAMOND_CU1000_1.dTo = BOX_CU1000_2.dTo THEN DIAMOND_CU1000_1.dTo
END AS dTo
FROM DIAMOND_CU1000_1, BOX_CU1000_2
WHERE
((DIAMOND_CU1000_1.dFrom > BOX_CU1000_2.dFrom AND BOX_CU1000_2.dTo > DIAMOND_CU1000_1.dFrom) OR (BOX_CU1000_2.dFrom > DIAMOND_CU1000_1.dFrom AND DIAMOND_CU1000_1.dTo > BOX_CU1000_2.dFrom) OR (DIAMOND_CU1000_1.dFrom = BOX_CU1000_2.dFrom)) AND
((DIAMOND_CU1000_1.dTo < BOX_CU1000_2.dTo AND DIAMOND_CU1000_1.dTo > BOX_CU1000_2.dFrom) OR (BOX_CU1000_2.dTo < DIAMOND_CU1000_1.dTo AND BOX_CU1000_2.dTo > DIAMOND_CU1000_1.dFrom) OR (DIAMOND_CU1000_1.dTo = BOX_CU1000_2.dTo)))

SELECT (dFrom + interval '10 seconds') AS dFrom, (dTo + interval '10 minutes 10 seconds') AS dTo FROM E;

CREATE TEMPORARY TABLE MF AS
WITH C0_MF AS (
SELECT * FROM tb_sensor_unified WHERE mainflame IS NOT NULL
),

C1_MF AS (
SELECT dFrom, dTo, currMf, nextMf
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
mainflame AS currMf,
LEAD(mainflame, 1) OVER (ORDER BY  datetime) AS nextMf
FROM C0_MF) F
WHERE currMF >= 1 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'
),

C2_MF (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_MF 
UNION ALL
SELECT 0, 1, dTo
FROM C1_MF  
),

C3_MF AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_MF
),

C4_MF AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_MF
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
)

SELECT (prevTs + interval '10 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_MF) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '10 seconds';

CREATE INDEX DIAMOND_E_IDX_FROM_TO ON DIAMOND_E (dFrom,dTo);
CREATE INDEX MF_IDX_FROM_TO ON MF (dFrom,dTo);

CREATE TEMPORARY TABLE PIO AS 
SELECT
CASE 
WHEN DIAMOND_E.dFrom > MF.dFrom AND MF.dTo > DIAMOND_E.dFrom THEN DIAMOND_E.dFrom
WHEN MF.dFrom > DIAMOND_E.dFrom AND DIAMOND_E.dTo > MF.dFrom THEN MF.dFrom
WHEN DIAMOND_E.dFrom = MF.dFrom THEN DIAMOND_E.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_E.dTo < MF.dTo AND DIAMOND_E.dTo > MF.dFrom THEN DIAMOND_E.dTo
WHEN MF.dTo < DIAMOND_E.dTo AND MF.dTo > DIAMOND_E.dFrom THEN MF.dTo
WHEN DIAMOND_E.dTo = MF.dTo THEN DIAMOND_E.dTo
END AS dTo
FROM DIAMOND_E, MF
WHERE
((DIAMOND_E.dFrom > MF.dFrom AND MF.dTo > DIAMOND_E.dFrom) OR (MF.dFrom > DIAMOND_E.dFrom AND DIAMOND_E.dTo > MF.dFrom) OR (DIAMOND_E.dFrom = MF.dFrom)) AND
((DIAMOND_E.dTo < MF.dTo AND DIAMOND_E.dTo > MF.dFrom) OR (MF.dTo < DIAMOND_E.dTo AND MF.dTo > DIAMOND_E.dFrom) OR (DIAMOND_E.dTo = MF.dTo));

CREATE INDEX PIO_IDX_FROM_TO ON PIO (dFrom,dTo);

CREATE TEMPORARY TABLE DIAMOND_C AS
WITH C AS (
SELECT
CASE 
WHEN DIAMOND_D.dFrom > PIO.dFrom AND PIO.dTo > DIAMOND_D.dFrom THEN DIAMOND_D.dFrom
WHEN PIO.dFrom > DIAMOND_D.dFrom AND DIAMOND_D.dTo > PIO.dFrom THEN PIO.dFrom
WHEN DIAMOND_D.dFrom = PIO.dFrom THEN DIAMOND_D.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_D.dTo < PIO.dTo AND DIAMOND_D.dTo > PIO.dFrom THEN DIAMOND_D.dTo
WHEN PIO.dTo < DIAMOND_D.dTo AND PIO.dTo > DIAMOND_D.dFrom THEN PIO.dTo
WHEN DIAMOND_D.dTo = PIO.dTo THEN DIAMOND_D.dTo
END AS dTo
FROM DIAMOND_D, PIO
WHERE
((DIAMOND_D.dFrom > PIO.dFrom AND PIO.dTo > DIAMOND_D.dFrom) OR (PIO.dFrom > DIAMOND_D.dFrom AND DIAMOND_D.dTo > PIO.dFrom) OR (DIAMOND_D.dFrom = PIO.dFrom)) AND
((DIAMOND_D.dTo < PIO.dTo AND DIAMOND_D.dTo > PIO.dFrom) OR (PIO.dTo < DIAMOND_D.dTo AND PIO.dTo > DIAMOND_D.dFrom) OR (DIAMOND_D.dTo = PIO.dTo))
)

SELECT (dFrom - interval '11 minutes') AS dFrom, dTo FROM C;

CREATE TEMPORARY TABLE DIAMOND_CD1 AS
WITH C0_CD1 AS (
SELECT * FROM tb_sensor_unified WHERE maxrotorspeed IS NOT NULL
),

C1_CD1 AS (
SELECT dFrom, dTo
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
maxrotorspeed AS currRs,
LEAD(maxrotorspeed, 1) OVER (ORDER BY  datetime) AS nextRs
FROM C0_CD1) F
WHERE currRs <= 200 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'
),

C2_CD1 (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_CD1
UNION ALL
SELECT 0, 1, dTo
FROM C1_CD1
),

C3_CD1 AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_CD1
),

C4_CD1 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_CD1
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
),

BOX_CD1 AS (
SELECT (prevTs + interval '30 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_CD1) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '30 seconds')

SELECT (dFrom + interval '30 seconds') AS dFrom, (dTo + interval '150 seconds') AS dTo FROM BOX_CD1;

CREATE TEMPORARY TABLE BOX_CD2 AS

WITH C0_CD2 AS (
SELECT * FROM tb_sensor_unified WHERE maxrotorspeed IS NOT NULL
),

C1_CD2 AS (
SELECT dFrom, dTo
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
maxrotorspeed AS currRs,
LEAD(maxrotorspeed, 1) OVER (ORDER BY  datetime) AS nextRs
FROM C0_CD2) F
WHERE currRs >= 1260 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'
),

C2_CD2 (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_CD2
UNION ALL
SELECT 0, 1, dTo
FROM C1_CD2
),

C3_CD2 AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_CD2
),

C4_CD2 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_CD2
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
)

SELECT (prevTs + interval '30 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_CD2) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '30 seconds';

CREATE INDEX DIAMOND_CD1_IDX_FROM_TO ON DIAMOND_CD1 (dFrom,dTo);
CREATE INDEX BOX_CD2_IDX_FROM_TO ON BOX_CD2 (dFrom,dTo);

CREATE TEMPORARY TABLE CU1260 AS
SELECT
CASE 
WHEN DIAMOND_CD1.dFrom > BOX_CD2.dFrom AND BOX_CD2.dTo > DIAMOND_CD1.dFrom THEN DIAMOND_CD1.dFrom
WHEN BOX_CD2.dFrom > DIAMOND_CD1.dFrom AND DIAMOND_CD1.dTo > BOX_CD2.dFrom THEN BOX_CD2.dFrom
WHEN DIAMOND_CD1.dFrom = BOX_CD2.dFrom THEN DIAMOND_CD1.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_CD1.dTo < BOX_CD2.dTo AND DIAMOND_CD1.dTo > BOX_CD2.dFrom THEN DIAMOND_CD1.dTo
WHEN BOX_CD2.dTo < DIAMOND_CD1.dTo AND BOX_CD2.dTo > DIAMOND_CD1.dFrom THEN BOX_CD2.dTo
WHEN DIAMOND_CD1.dTo = BOX_CD2.dTo THEN DIAMOND_CD1.dTo
END AS dTo
FROM DIAMOND_CD1, BOX_CD2
WHERE
((DIAMOND_CD1.dFrom > BOX_CD2.dFrom AND BOX_CD2.dTo > DIAMOND_CD1.dFrom) OR (BOX_CD2.dFrom > DIAMOND_CD1.dFrom AND DIAMOND_CD1.dTo > BOX_CD2.dFrom) OR (DIAMOND_CD1.dFrom = BOX_CD2.dFrom)) AND
((DIAMOND_CD1.dTo < BOX_CD2.dTo AND DIAMOND_CD1.dTo > BOX_CD2.dFrom) OR (BOX_CD2.dTo < DIAMOND_CD1.dTo AND BOX_CD2.dTo > DIAMOND_CD1.dFrom) OR (DIAMOND_CD1.dTo = BOX_CD2.dTo));

CREATE INDEX DIAMOND_C_IDX_FROM_TO ON DIAMOND_C (dFrom,dTo);
CREATE INDEX CU1260_IDX_FROM_TO ON CU1260 (dFrom,dTo);

CREATE TEMPORARY TABLE DIAMOND_B AS
WITH B AS (
SELECT
CASE 
WHEN DIAMOND_C.dFrom > CU1260.dFrom AND CU1260.dTo > DIAMOND_C.dFrom THEN DIAMOND_C.dFrom
WHEN CU1260.dFrom > DIAMOND_C.dFrom AND DIAMOND_C.dTo > CU1260.dFrom THEN CU1260.dFrom
WHEN DIAMOND_C.dFrom = CU1260.dFrom THEN DIAMOND_C.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_C.dTo < CU1260.dTo AND DIAMOND_C.dTo > CU1260.dFrom THEN DIAMOND_C.dTo
WHEN CU1260.dTo < DIAMOND_C.dTo AND CU1260.dTo > DIAMOND_C.dFrom THEN CU1260.dTo
WHEN DIAMOND_C.dTo = CU1260.dTo THEN DIAMOND_C.dTo
END AS dTo
FROM DIAMOND_C, CU1260
WHERE
((DIAMOND_C.dFrom > CU1260.dFrom AND CU1260.dTo > DIAMOND_C.dFrom) OR (CU1260.dFrom > DIAMOND_C.dFrom AND DIAMOND_C.dTo > CU1260.dFrom) OR (DIAMOND_C.dFrom = CU1260.dFrom)) AND
((DIAMOND_C.dTo < CU1260.dTo AND DIAMOND_C.dTo > CU1260.dFrom) OR (CU1260.dTo < DIAMOND_C.dTo AND CU1260.dTo > DIAMOND_C.dFrom) OR (DIAMOND_C.dTo = CU1260.dTo))
)

SELECT (dFrom - interval '15 seconds') AS dFrom, dTo FROM B;

CREATE TEMPORARY TABLE DIAMOND_CD1_1 AS
WITH C0_CD1_1 AS (
SELECT * FROM tb_sensor_unified WHERE maxrotorspeed IS NOT NULL
),

C1_CD1_1 AS (
SELECT dFrom, dTo
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
maxrotorspeed AS currRs,
LEAD(maxrotorspeed, 1) OVER (ORDER BY  datetime) AS nextRs
FROM C0_CD1_1) F
WHERE currRs <= 60 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'
),

C2_CD1_1 (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_CD1_1
UNION ALL
SELECT 0, 1, dTo
FROM C1_CD1_1
),

C3_CD1_1 AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_CD1_1
),

C4_CD1_1 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_CD1_1
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
),

BOX_CD1_1 AS (
SELECT (prevTs + interval '60 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_CD1_1) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '60 seconds')

SELECT (dFrom + interval '60 seconds') AS dFrom, (dTo + interval '150 seconds') AS dTo FROM BOX_CD1_1;

CREATE TEMPORARY TABLE BOX_CD2_1 AS
WITH C0_CD2_1 AS (
SELECT * FROM tb_sensor_unified WHERE maxrotorspeed IS NOT NULL
),

C1_CD2_1 AS (
SELECT dFrom, dTo
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
maxrotorspeed AS currRs,
LEAD(maxrotorspeed, 1) OVER (ORDER BY  datetime) AS nextRs
FROM C0_CD2_1) F
WHERE currRs >= 180 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'
),

C2_CD2_1 (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_CD2_1
UNION ALL
SELECT 0, 1, dTo
FROM C1_CD2_1
),

C3_CD2_1 AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_CD2_1
),

C4_CD2_1 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_CD2_1
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
)

SELECT (prevTs + interval '30 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_CD2_1) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '30 seconds';

CREATE INDEX DIAMOND_CD1_1_IDX_FROM_TO ON DIAMOND_CD1_1 (dFrom,dTo);
CREATE INDEX BOX_CD2_1_IDX_FROM_TO ON BOX_CD2_1 (dFrom,dTo);

CREATE TEMPORARY TABLE CU180 AS 
SELECT
CASE 
WHEN DIAMOND_CD1_1.dFrom > BOX_CD2_1.dFrom AND BOX_CD2_1.dTo > DIAMOND_CD1_1.dFrom THEN DIAMOND_CD1_1.dFrom
WHEN BOX_CD2_1.dFrom > DIAMOND_CD1_1.dFrom AND DIAMOND_CD1_1.dTo > BOX_CD2_1.dFrom THEN BOX_CD2_1.dFrom
WHEN DIAMOND_CD1_1.dFrom = BOX_CD2_1.dFrom THEN DIAMOND_CD1_1.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_CD1_1.dTo < BOX_CD2_1.dTo AND DIAMOND_CD1_1.dTo > BOX_CD2_1.dFrom THEN DIAMOND_CD1_1.dTo
WHEN BOX_CD2_1.dTo < DIAMOND_CD1_1.dTo AND BOX_CD2_1.dTo > DIAMOND_CD1_1.dFrom THEN BOX_CD2_1.dTo
WHEN DIAMOND_CD1_1.dTo = BOX_CD2_1.dTo THEN DIAMOND_CD1_1.dTo
END AS dTo
FROM DIAMOND_CD1_1, BOX_CD2_1
WHERE
((DIAMOND_CD1_1.dFrom > BOX_CD2_1.dFrom AND BOX_CD2_1.dTo > DIAMOND_CD1_1.dFrom) OR (BOX_CD2_1.dFrom > DIAMOND_CD1_1.dFrom AND DIAMOND_CD1_1.dTo > BOX_CD2_1.dFrom) OR (DIAMOND_CD1_1.dFrom = BOX_CD2_1.dFrom)) AND
((DIAMOND_CD1_1.dTo < BOX_CD2_1.dTo AND DIAMOND_CD1_1.dTo > BOX_CD2_1.dFrom) OR (BOX_CD2_1.dTo < DIAMOND_CD1_1.dTo AND BOX_CD2_1.dTo > DIAMOND_CD1_1.dFrom) OR (DIAMOND_CD1_1.dTo = BOX_CD2_1.dTo));

CREATE INDEX DIAMOND_B_IDX_FROM_TO ON DIAMOND_B (dFrom,dTo);
CREATE INDEX CU180_IDX_FROM_TO ON CU180 (dFrom,dTo);

CREATE TEMPORARY TABLE DIAMOND_NORMALSTART AS
WITH NORMALSTART AS (
SELECT
CASE 
WHEN DIAMOND_B.dFrom > CU180.dFrom AND CU180.dTo > DIAMOND_B.dFrom THEN DIAMOND_B.dFrom
WHEN CU180.dFrom > DIAMOND_B.dFrom AND DIAMOND_B.dTo > CU180.dFrom THEN CU180.dFrom
WHEN DIAMOND_B.dFrom = CU180.dFrom THEN DIAMOND_B.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_B.dTo < CU180.dTo AND DIAMOND_B.dTo > CU180.dFrom THEN DIAMOND_B.dTo
WHEN CU180.dTo < DIAMOND_B.dTo AND CU180.dTo > DIAMOND_B.dFrom THEN CU180.dTo
WHEN DIAMOND_B.dTo = CU180.dTo THEN DIAMOND_B.dTo
END AS dTo
FROM DIAMOND_B, CU180
WHERE
((DIAMOND_B.dFrom > CU180.dFrom AND CU180.dTo > DIAMOND_B.dFrom) OR (CU180.dFrom > DIAMOND_B.dFrom AND DIAMOND_B.dTo > CU180.dFrom) OR (DIAMOND_B.dFrom = CU180.dFrom)) AND
((DIAMOND_B.dTo < CU180.dTo AND DIAMOND_B.dTo > CU180.dFrom) OR (CU180.dTo < DIAMOND_B.dTo AND CU180.dTo > DIAMOND_B.dFrom) OR (DIAMOND_B.dTo = CU180.dTo)))

SELECT (dFrom - interval '1 hour') as dFrom, dTo FROM NORMALSTART;

CREATE TEMPORARY TABLE DIAMOND_CD1500_1 AS
WITH C0_CD1500_1 AS (
SELECT * FROM  tb_sensor_unified WHERE maxrotorspeed IS NOT NULL
),

C1_CD1500_1 AS (
SELECT dFrom, dTo
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
maxrotorspeed AS currRs,
LEAD(maxrotorspeed, 1) OVER (ORDER BY  datetime) AS nextRs
FROM C0_CD1500_1) F
WHERE currRs >= 1500 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'
),

C2_CD1500_1 (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_CD1500_1 
UNION ALL
SELECT 0, 1, dTo
FROM C1_CD1500_1  
),

C3_CD1500_1 AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_CD1500_1
),

C4_CD1500_1 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_CD1500_1
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
),

CD1500_1 AS (
SELECT (prevTs + interval '30 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_CD1500_1) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '30 seconds')

SELECT (dFrom + interval '30 seconds') AS dFrom, (dTo + interval '8 minutes') AS dTo FROM CD1500_1;

CREATE TEMPORARY TABLE CD1500_2 AS 
WITH C0_CD1500_2 AS (
SELECT * FROM  tb_sensor_unified WHERE maxrotorspeed IS NOT NULL
),

C1_CD1500_2 AS (
SELECT dFrom, dTo
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
maxrotorspeed AS currRs,
LEAD(maxrotorspeed, 1) OVER (ORDER BY  datetime) AS nextRs
FROM C0_CD1500_2) F
WHERE currRs <= 200 AND dTo IS NOT NULL
),

C2_CD1500_2 (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_CD1500_2 
UNION ALL
SELECT 0, 1, dTo
FROM C1_CD1500_2  
),

C3_CD1500_2 AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_CD1500_2
),

C4_CD1500_2 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_CD1500_2
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
)

SELECT (prevTs + interval '30 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_CD1500_2) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '30 seconds';

CREATE INDEX DIAMOND_CD1500_1_IDX_FROM_TO ON DIAMOND_CD1500_1 (dFrom,dTo);
CREATE INDEX CD1500_2_IDX_FROM_TO ON CD1500_2 (dFrom,dTo);

CREATE TEMPORARY TABLE DIAMOND_D_1 AS
WITH D AS (
SELECT
CASE 
WHEN DIAMOND_CD1500_1.dFrom > CD1500_2.dFrom AND CD1500_2.dTo > DIAMOND_CD1500_1.dFrom THEN DIAMOND_CD1500_1.dFrom
WHEN CD1500_2.dFrom > DIAMOND_CD1500_1.dFrom AND DIAMOND_CD1500_1.dTo > CD1500_2.dFrom THEN CD1500_2.dFrom
WHEN DIAMOND_CD1500_1.dFrom = CD1500_2.dFrom THEN DIAMOND_CD1500_1.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_CD1500_1.dTo < CD1500_2.dTo AND DIAMOND_CD1500_1.dTo > CD1500_2.dFrom THEN DIAMOND_CD1500_1.dTo
WHEN CD1500_2.dTo < DIAMOND_CD1500_1.dTo AND CD1500_2.dTo > DIAMOND_CD1500_1.dFrom THEN CD1500_2.dTo
WHEN DIAMOND_CD1500_1.dTo = CD1500_2.dTo THEN DIAMOND_CD1500_1.dTo
END AS dTo
FROM DIAMOND_CD1500_1, CD1500_2
WHERE
((DIAMOND_CD1500_1.dFrom > CD1500_2.dFrom AND CD1500_2.dTo > DIAMOND_CD1500_1.dFrom) OR (CD1500_2.dFrom > DIAMOND_CD1500_1.dFrom AND DIAMOND_CD1500_1.dTo > CD1500_2.dFrom) OR (DIAMOND_CD1500_1.dFrom = CD1500_2.dFrom)) AND
((DIAMOND_CD1500_1.dTo < CD1500_2.dTo AND DIAMOND_CD1500_1.dTo > CD1500_2.dFrom) OR (CD1500_2.dTo < DIAMOND_CD1500_1.dTo AND CD1500_2.dTo > DIAMOND_CD1500_1.dFrom) OR (DIAMOND_CD1500_1.dTo = CD1500_2.dTo)))

SELECT (dFrom - interval '9 minutes') as dFrom, dTo FROM D;

CREATE TEMPORARY TABLE DIAMOND_CD6600_1 AS
WITH C0_CD6600_1 AS (
SELECT * FROM  tb_sensor_unified WHERE maxrotorspeed IS NOT NULL
),

C1_CD6600_1 AS (
SELECT dFrom, dTo
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
maxrotorspeed AS currRs,
LEAD(maxrotorspeed, 1) OVER (ORDER BY  datetime) AS nextRs
FROM C0_CD6600_1) F
WHERE currRs >= 6600 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'
),

C2_CD6600_1 (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_CD6600_1 
UNION ALL
SELECT 0, 1, dTo
FROM C1_CD6600_1  
),

C3_CD6600_1 AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_CD6600_1
),

C4_CD6600_1 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_CD6600_1
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
),

CD6600_1 AS (
SELECT (prevTs + interval '30 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_CD6600_1) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '30 seconds')

SELECT (dFrom + interval '30 seconds') AS dFrom, (dTo + interval '150 seconds') AS dTo FROM CD6600_1;

CREATE TEMPORARY TABLE CD6600_2 AS
WITH C0_CD6600_2 AS (
SELECT * FROM  tb_sensor_unified WHERE maxrotorspeed IS NOT NULL
),

C1_CD6600_2 AS (
SELECT dFrom, dTo
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
maxrotorspeed AS currRs,
LEAD(maxrotorspeed, 1) OVER (ORDER BY  datetime) AS nextRs
FROM C0_CD6600_2) F
WHERE currRs <= 1500 AND dTo IS NOT NULL
),

C2_CD6600_2 (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_CD6600_2 
UNION ALL
SELECT 0, 1, dTo
FROM C1_CD6600_2  
),

C3_CD6600_2 AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_CD6600_2
),

C4_CD6600_2 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_CD6600_2
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
)

SELECT (prevTs + interval '30 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_CD6600_2) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '30 seconds';

CREATE INDEX DIAMOND_CD6600_1_IDX_FROM_TO ON DIAMOND_CD6600_1 (dFrom,dTo);
CREATE INDEX CD6600_2_IDX_FROM_TO ON CD6600_2 (dFrom,dTo);

CREATE TEMPORARY TABLE C AS 
SELECT
CASE 
WHEN DIAMOND_CD6600_1.dFrom > CD6600_2.dFrom AND CD6600_2.dTo > DIAMOND_CD6600_1.dFrom THEN DIAMOND_CD6600_1.dFrom
WHEN CD6600_2.dFrom > DIAMOND_CD6600_1.dFrom AND DIAMOND_CD6600_1.dTo > CD6600_2.dFrom THEN CD6600_2.dFrom
WHEN DIAMOND_CD6600_1.dFrom = CD6600_2.dFrom THEN DIAMOND_CD6600_1.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_CD6600_1.dTo < CD6600_2.dTo AND DIAMOND_CD6600_1.dTo > CD6600_2.dFrom THEN DIAMOND_CD6600_1.dTo
WHEN CD6600_2.dTo < DIAMOND_CD6600_1.dTo AND CD6600_2.dTo > DIAMOND_CD6600_1.dFrom THEN CD6600_2.dTo
WHEN DIAMOND_CD6600_1.dTo = CD6600_2.dTo THEN DIAMOND_CD6600_1.dTo
END AS dTo
FROM DIAMOND_CD6600_1, CD6600_2
WHERE
((DIAMOND_CD6600_1.dFrom > CD6600_2.dFrom AND CD6600_2.dTo > DIAMOND_CD6600_1.dFrom) OR (CD6600_2.dFrom > DIAMOND_CD6600_1.dFrom AND DIAMOND_CD6600_1.dTo > CD6600_2.dFrom) OR (DIAMOND_CD6600_1.dFrom = CD6600_2.dFrom)) AND
((DIAMOND_CD6600_1.dTo < CD6600_2.dTo AND DIAMOND_CD6600_1.dTo > CD6600_2.dFrom) OR (CD6600_2.dTo < DIAMOND_CD6600_1.dTo AND CD6600_2.dTo > DIAMOND_CD6600_1.dFrom) OR (DIAMOND_CD6600_1.dTo = CD6600_2.dTo));

CREATE INDEX DIAMOND_D_1_IDX_FROM_TO ON DIAMOND_D_1 (dFrom,dTo);
CREATE INDEX C_IDX_FROM_TO ON C (dFrom,dTo);

CREATE TEMPORARY TABLE DIAMOND_E_1 AS 
WITH E AS (
SELECT
CASE 
WHEN DIAMOND_D_1.dFrom > C.dFrom AND C.dTo > DIAMOND_D_1.dFrom THEN DIAMOND_D_1.dFrom
WHEN C.dFrom > DIAMOND_D_1.dFrom AND DIAMOND_D_1.dTo > C.dFrom THEN C.dFrom
WHEN DIAMOND_D_1.dFrom = C.dFrom THEN DIAMOND_D_1.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_D_1.dTo < C.dTo AND DIAMOND_D_1.dTo > C.dFrom THEN DIAMOND_D_1.dTo
WHEN C.dTo < DIAMOND_D_1.dTo AND C.dTo > DIAMOND_D_1.dFrom THEN C.dTo
WHEN DIAMOND_D_1.dTo = C.dTo THEN DIAMOND_D_1.dTo
END AS dTo
FROM DIAMOND_D_1, C
WHERE
((DIAMOND_D_1.dFrom > C.dFrom AND C.dTo > DIAMOND_D_1.dFrom) OR (C.dFrom > DIAMOND_D_1.dFrom AND DIAMOND_D_1.dTo > C.dFrom) OR (DIAMOND_D_1.dFrom = C.dFrom)) AND
((DIAMOND_D_1.dTo < C.dTo AND DIAMOND_D_1.dTo > C.dFrom) OR (C.dTo < DIAMOND_D_1.dTo AND C.dTo > DIAMOND_D_1.dFrom) OR (DIAMOND_D_1.dTo = C.dTo)))

SELECT (dFrom - interval '2 minutes') as dFrom, dTo FROM E;

CREATE TEMPORARY TABLE B_1 AS
WITH C0_MF AS (
SELECT * FROM  tb_sensor_unified WHERE mainflame IS NOT NULL
),

C1_MF AS (
SELECT dFrom, dTo, currMf, nextMf
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
mainflame AS currMf,
LEAD(mainflame, 1) OVER (ORDER BY  datetime) AS nextMf
FROM C0_MF) F
WHERE currMF <= 0.1 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'
),

C2_MF (Start_ts, End_ts, ts) AS (
SELECT 1, 0 , dFrom
FROM C1_MF 
UNION ALL
SELECT 0, 1, dTo
FROM C1_MF  
),

C3_MF AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_MF
),

C4_MF AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_MF
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
)

SELECT (prevTs + interval '10 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_MF) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '10 seconds';

CREATE INDEX DIAMOND_E_1_IDX_FROM_TO ON DIAMOND_E_1 (dFrom,dTo);
CREATE INDEX B_1_IDX_FROM_TO ON B_1 (dFrom,dTo);

CREATE TEMPORARY TABLE DIAMOND_F AS
WITH F AS (
SELECT
CASE 
WHEN DIAMOND_E_1.dFrom > B_1.dFrom AND B_1.dTo > DIAMOND_E_1.dFrom THEN DIAMOND_E_1.dFrom
WHEN B_1.dFrom > DIAMOND_E_1.dFrom AND DIAMOND_E_1.dTo > B_1.dFrom THEN B_1.dFrom
WHEN DIAMOND_E_1.dFrom = B_1.dFrom THEN DIAMOND_E_1.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_E_1.dTo < B_1.dTo AND DIAMOND_E_1.dTo > B_1.dFrom THEN DIAMOND_E_1.dTo
WHEN B_1.dTo < DIAMOND_E_1.dTo AND B_1.dTo > DIAMOND_E_1.dFrom THEN B_1.dTo
WHEN DIAMOND_E_1.dTo = B_1.dTo THEN DIAMOND_E_1.dTo
END AS dTo
FROM DIAMOND_E_1, B_1
WHERE
((DIAMOND_E_1.dFrom > B_1.dFrom AND B_1.dTo > DIAMOND_E_1.dFrom) OR (B_1.dFrom > DIAMOND_E_1.dFrom AND DIAMOND_E_1.dTo > B_1.dFrom) OR (DIAMOND_E_1.dFrom = B_1.dFrom)) AND
((DIAMOND_E_1.dTo < B_1.dTo AND DIAMOND_E_1.dTo > B_1.dFrom) OR (B_1.dTo < DIAMOND_E_1.dTo AND B_1.dTo > DIAMOND_E_1.dFrom) OR (DIAMOND_E_1.dTo = B_1.dTo)))

SELECT (dFrom - interval '2 minutes') as dFrom, dTo FROM F;

CREATE TEMPORARY TABLE A_1 AS
WITH C0_AP AS (
SELECT * FROM  tb_sensor_unified WHERE activepower IS NOT NULL
),

C1_AP AS (
SELECT dFrom, dTo, currAp, nextAp 
FROM (
SELECT datetime as dFrom,
LEAD(datetime, 1) OVER (ORDER BY  datetime) AS dTo,
activepower AS currAp,
LEAD(activepower, 1) OVER (ORDER BY  datetime) AS nextAp
FROM C0_AP) F
WHERE currAp <= 0.15 AND dTo IS NOT NULL AND dTo - dFrom <= interval '1 day'),

C2_AP (Start_ts, End_ts, ts) AS (
SELECT 1, 0, dFrom 
FROM C1_AP 
UNION ALL
SELECT 0, 1, dTo 
FROM C1_AP  
),

C3_AP AS (
SELECT 
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts
FROM C2_AP
),

C4_AP AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts
FROM C3_AP
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
)

SELECT (prevTs + interval '30 seconds') AS dFrom, ts AS dTo FROM (
SELECT LAG(ts,1) OVER (ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C4_AP) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '30 seconds';

CREATE INDEX DIAMOND_F_IDX_FROM_TO ON DIAMOND_F (dFrom,dTo);
CREATE INDEX A_1_IDX_FROM_TO ON A_1 (dFrom,dTo);

CREATE TEMPORARY TABLE NORMALSTOP AS 
SELECT
CASE 
WHEN DIAMOND_F.dFrom > A_1.dFrom AND A_1.dTo > DIAMOND_F.dFrom THEN DIAMOND_F.dFrom
WHEN A_1.dFrom > DIAMOND_F.dFrom AND DIAMOND_F.dTo > A_1.dFrom THEN A_1.dFrom
WHEN DIAMOND_F.dFrom = A_1.dFrom THEN DIAMOND_F.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_F.dTo < A_1.dTo AND DIAMOND_F.dTo > A_1.dFrom THEN DIAMOND_F.dTo
WHEN A_1.dTo < DIAMOND_F.dTo AND A_1.dTo > DIAMOND_F.dFrom THEN A_1.dTo
WHEN DIAMOND_F.dTo = A_1.dTo THEN DIAMOND_F.dTo
END AS dTo
FROM DIAMOND_F, A_1
WHERE
((DIAMOND_F.dFrom > A_1.dFrom AND A_1.dTo > DIAMOND_F.dFrom) OR (A_1.dFrom > DIAMOND_F.dFrom AND DIAMOND_F.dTo > A_1.dFrom) OR (DIAMOND_F.dFrom = A_1.dFrom)) AND
((DIAMOND_F.dTo < A_1.dTo AND DIAMOND_F.dTo > A_1.dFrom) OR (A_1.dTo < DIAMOND_F.dTo AND A_1.dTo > DIAMOND_F.dFrom) OR (DIAMOND_F.dTo = A_1.dTo));

CREATE INDEX DIAMOND_NORMALSTART_IDX_FROM_TO ON DIAMOND_NORMALSTART (dFrom,dTo);
CREATE INDEX NORMALSTOP_IDX_FROM_TO ON NORMALSTOP (dFrom,dTo);

SELECT
CASE 
WHEN DIAMOND_NORMALSTART.dFrom > NORMALSTOP.dFrom AND NORMALSTOP.dTo > DIAMOND_NORMALSTART.dFrom THEN DIAMOND_NORMALSTART.dFrom
WHEN NORMALSTOP.dFrom > DIAMOND_NORMALSTART.dFrom AND DIAMOND_NORMALSTART.dTo > NORMALSTOP.dFrom THEN NORMALSTOP.dFrom
WHEN DIAMOND_NORMALSTART.dFrom = NORMALSTOP.dFrom THEN DIAMOND_NORMALSTART.dFrom
END AS dFrom,
CASE 
WHEN DIAMOND_NORMALSTART.dTo < NORMALSTOP.dTo AND DIAMOND_NORMALSTART.dTo > NORMALSTOP.dFrom THEN DIAMOND_NORMALSTART.dTo
WHEN NORMALSTOP.dTo < DIAMOND_NORMALSTART.dTo AND NORMALSTOP.dTo > DIAMOND_NORMALSTART.dFrom THEN NORMALSTOP.dTo
WHEN DIAMOND_NORMALSTART.dTo = NORMALSTOP.dTo THEN DIAMOND_NORMALSTART.dTo
END AS dTo
FROM DIAMOND_NORMALSTART, NORMALSTOP
WHERE
((DIAMOND_NORMALSTART.dFrom > NORMALSTOP.dFrom AND NORMALSTOP.dTo > DIAMOND_NORMALSTART.dFrom) OR (NORMALSTOP.dFrom > DIAMOND_NORMALSTART.dFrom AND DIAMOND_NORMALSTART.dTo > NORMALSTOP.dFrom) OR (DIAMOND_NORMALSTART.dFrom = NORMALSTOP.dFrom)) AND
((DIAMOND_NORMALSTART.dTo < NORMALSTOP.dTo AND DIAMOND_NORMALSTART.dTo > NORMALSTOP.dFrom) OR (NORMALSTOP.dTo < DIAMOND_NORMALSTART.dTo AND NORMALSTOP.dTo > DIAMOND_NORMALSTART.dFrom) OR (DIAMOND_NORMALSTART.dTo = NORMALSTOP.dTo));