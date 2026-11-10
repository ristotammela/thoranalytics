SET preserve_insertion_order = false;

SET variable input_path  = 'THOR_Vietnam_Bombing_Operations.parquet';

CREATE TEMP TABLE temp_stage_table AS
SELECT  
        *,
        CASE 
            WHEN OPERATIONSUPPORTED ILIKE '%BARREL ROLL%' THEN 'BARREL ROLL'
            WHEN OPERATIONSUPPORTED ILIKE '%STEEL TIGER%' THEN 'STEEL TIGER'
            WHEN OPERATIONSUPPORTED ILIKE '%TIGER HOUND%' THEN 'TIGER HOUND'
            WHEN OPERATIONSUPPORTED ILIKE '%IGLOO WHITE%' THEN 'IGLOO WHITE'
            ELSE NULL
        END AS operationhochiminhtrail,
        try_strptime(MSNDATE, ['%Y-%m-%d', '%Y%m%d'])::DATE AS missiondate, 
    
FROM read_parquet(getvariable('input_path'));

DELETE FROM 
temp_stage_table 
WHERE   THOR_DATA_VIET_ID IS NULL 
        OR TGTLONDDD_DDD_WGS84 IS NULL 
        OR TGTLATDD_DDD_WGS84 IS NULL
        OR TGTLONDDD_DDD_WGS84 < 100
        OR TGTLONDDD_DDD_WGS84 > 110
        OR TGTLATDD_DDD_WGS84 < 7.5
        OR TGTLATDD_DDD_WGS84 > 22.5
        ;

COPY (
    SELECT 
        THOR_DATA_VIET_ID,
        TGTLONDDD_DDD_WGS84,
        TGTLATDD_DDD_WGS84,
        OPERATIONSUPPORTED,
        missiondate,
        operationhochiminhtrail,
        FLTHOURS,
        WEAPONTYPE,
        AIRCRAFT_ROOT,
        TGTCOUNTRY
    FROM temp_stage_table
) 
TO 'THOR_Analysis.parquet'
(FORMAT 'parquet', COMPRESSION 'zstd');
