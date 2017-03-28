CREATE TEMPORARY TABLE BOX_ABOVE24 AS
WITH ABOVE24 AS (
SELECT SID, dFrom, dTo
FROM (SELECT station_id AS SID,
lag(date_time, 1) OVER (PARTITION BY station_id ORDER BY  date_time) AS dFrom,
date_time AS dTo,
lag(air_temp_set_1, 1) OVER (PARTITION BY station_id ORDER BY  date_time) AS prevTemp,
air_temp_set_1 AS currTemp,
ROW_NUMBER() OVER(PARTITION BY station_id ORDER BY date_time) AS rnm
FROM tb_newyorkdata2005) AS a
WHERE currTemp >= 24 AND rnm > 1 AND dTo - dFrom <= interval '1 day'),

C1_ABOVE24 (Start_ts, End_ts, ts, SID) AS (
SELECT 1, 0 , dFrom, SID
FROM ABOVE24 
UNION ALL
SELECT 0, 1, dTo, SID
FROM ABOVE24  
),

C2_ABOVE24 AS (
SELECT 
SUM(Start_ts) OVER (PARTITION BY SID ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (PARTITION BY SID ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (PARTITION BY SID ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (PARTITION BY SID ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts,
SID
FROM C1_ABOVE24
),

C3_ABOVE24 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts, SID 
FROM C2_ABOVE24
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
)

SELECT SID, (prevTs + interval '24 hours') AS daFrom, ts AS daTo FROM (
SELECT SID, LAG(ts,1) OVER (PARTITION BY SID ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C3_ABOVE24) F 
WHERE Crt_Total_ts = 0 AND ts - prevTs >= interval '24 hours';

CREATE TEMPORARY TABLE DIAMOND_ABOVE41 AS
WITH ABOVE41 AS (
SELECT SID, dFrom, dTo, prevTemp, currTemp
FROM (SELECT station_id AS SID,
lag(date_time, 1) OVER (PARTITION BY station_id ORDER BY  date_time) AS dFrom,
date_time AS dTo,
lag(air_temp_set_1, 1) OVER (PARTITION BY station_id ORDER BY  date_time) AS prevTemp,
air_temp_set_1 AS currTemp,
ROW_NUMBER() OVER(PARTITION BY station_id ORDER BY date_time) AS rnm
FROM tb_newyorkdata2005) AS a
WHERE currTemp >= 41 AND rnm > 1 AND dTo - dFrom <= interval '1 day'),

C1_ABOVE41 (Start_ts, End_ts, ts, SID) AS (
SELECT 1, 0 , dFrom, SID
FROM ABOVE41 
UNION ALL
SELECT 0, 1, dTo, SID
FROM ABOVE41  
),

C2_ABOVE41 AS (
SELECT 
SUM(Start_ts) OVER (PARTITION BY SID ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (PARTITION BY SID ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (PARTITION BY SID ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (PARTITION BY SID ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts,
SID
FROM C1_ABOVE41
),

C3_ABOVE41 AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts, SID 
FROM C2_ABOVE41
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
),

C4_ABOVE41 AS (
SELECT SID, prevTs AS dFrom, ts AS dTo FROM (
SELECT SID, LAG(ts,1) OVER (PARTITION BY SID ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM C3_ABOVE41) F 
WHERE Crt_Total_ts = 0)

SELECT SID, dFrom AS shFrom, (dTo + interval '24 hours') AS shTo
FROM C4_ABOVE41;

CREATE INDEX BOX_ABOVE24_IDX_FROM_TO ON BOX_ABOVE24 (daFrom,daTo);
CREATE INDEX DIAMOND_ABOVE41_IDX_FROM_TO ON DIAMOND_ABOVE41 (shFrom,shTo);

WITH EXCESSIVE_HEAT AS (
SELECT BOX_ABOVE24.SID AS SID,
CASE 
WHEN BOX_ABOVE24.daFrom > DIAMOND_ABOVE41.shFrom AND DIAMOND_ABOVE41.shTo > BOX_ABOVE24.daFrom THEN (BOX_ABOVE24.daFrom - interval '24 hours')
WHEN DIAMOND_ABOVE41.shFrom > BOX_ABOVE24.daFrom AND BOX_ABOVE24.daTo > DIAMOND_ABOVE41.shFrom THEN (DIAMOND_ABOVE41.shFrom - interval '24 hours')
WHEN BOX_ABOVE24.daFrom = DIAMOND_ABOVE41.shFrom THEN (BOX_ABOVE24.daFrom - interval '24 hours')
END AS dFrom,
CASE 
WHEN BOX_ABOVE24.daTo < DIAMOND_ABOVE41.shTo AND BOX_ABOVE24.daTo > DIAMOND_ABOVE41.shFrom THEN BOX_ABOVE24.daTo
WHEN DIAMOND_ABOVE41.shTo < BOX_ABOVE24.daTo AND DIAMOND_ABOVE41.shTo > BOX_ABOVE24.daFrom THEN DIAMOND_ABOVE41.shTo
WHEN BOX_ABOVE24.daTo = DIAMOND_ABOVE41.shTo THEN BOX_ABOVE24.daTo
END AS dTo
FROM BOX_ABOVE24, DIAMOND_ABOVE41
WHERE BOX_ABOVE24.SID = DIAMOND_ABOVE41.SID AND 
((BOX_ABOVE24.daFrom > DIAMOND_ABOVE41.shFrom AND DIAMOND_ABOVE41.shTo > BOX_ABOVE24.daFrom) OR (DIAMOND_ABOVE41.shFrom > BOX_ABOVE24.daFrom AND BOX_ABOVE24.daTo > DIAMOND_ABOVE41.shFrom) OR (BOX_ABOVE24.daFrom = DIAMOND_ABOVE41.shFrom)) AND
((BOX_ABOVE24.daTo < DIAMOND_ABOVE41.shTo AND BOX_ABOVE24.daTo > DIAMOND_ABOVE41.shFrom) OR (DIAMOND_ABOVE41.shTo < BOX_ABOVE24.daTo AND DIAMOND_ABOVE41.shTo > BOX_ABOVE24.daFrom) OR (BOX_ABOVE24.daTo = DIAMOND_ABOVE41.shTo))),

L1_EH AS (
SELECT county, dFrom, dTo FROM tb_metadata, EXCESSIVE_HEAT WHERE stid = SID
),

L2_EH (Start_ts, End_ts, ts, county) AS (
SELECT 1, 0 , dFrom, county
FROM L1_EH
UNION ALL
SELECT 0, 1, dTo, county
FROM L1_EH
),

L3_EH AS (
SELECT 
SUM(Start_ts) OVER (PARTITION BY county ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_1,
SUM(End_ts) OVER (PARTITION BY county ORDER BY ts, End_ts ROWS UNBOUNDED PRECEDING) AS Crt_Total_ts_2,
SUM(Start_ts) OVER (PARTITION BY county ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_1,
SUM(End_ts) OVER (PARTITION BY county ORDER BY ts, End_ts ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Prv_Total_ts_2,
ts,
county
FROM L2_EH
),

L4_EH AS (
SELECT (Crt_Total_ts_1 - Crt_Total_ts_2) AS Crt_Total_ts, (Prv_Total_ts_1 - Prv_Total_ts_2) AS Prv_Total_ts, ts, county 
FROM L3_EH
WHERE (Crt_Total_ts_1 - Crt_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) = 0 OR (Prv_Total_ts_1 - Prv_Total_ts_2) IS NULL
)

SELECT county, prevTs AS dFrom, ts AS dTo FROM (
SELECT county, LAG(ts,1) OVER (PARTITION BY county ORDER BY ts, crt_total_ts) As prevTs,
ts,
Crt_Total_ts
FROM L4_EH) F 
WHERE Crt_Total_ts = 0;