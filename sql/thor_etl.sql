SET preserve_insertion_order = false;

SET variable input_path  = 'THOR_Vietnam_Bombing_Operations.parquet';

## Extract base values from the input Parquet file

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
        'UNDEFINED' AS WEAPON_CLASS,
        'UNDEFINED' AS RESULTSBDATYPE
FROM read_parquet(getvariable('input_path'));

## Map weapon types to weapon classes

CREATE TEMP TABLE map_weapons AS
SELECT *
FROM read_csv_auto(
    'THOR_Vietnam_Weapons_Glossary.csv',
    header = true,
    encoding = 'latin-1'
);

UPDATE temp_stage_table
SET WEAPON_CLASS = map_weapons.WEAPON_CLASS
FROM map_weapons
WHERE temp_stage_table.WEAPONTYPE = map_weapons.WEAPONTYPE;

UPDATE temp_stage_table
SET RESULTSBDATYPE = 'RNO'
WHERE RESULTSBDA like 'RNO%';


UPDATE temp_stage_table
SET RESULTSBDATYPE = 'OBSERVED'
WHERE RESULTSBDATYPE <> 'RNO' AND RESULTSBDA IS NOT NULL;

# remove rows with null or out-of-bounds coordinates
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

# remove SEADAB B-52 records

DELETE FROM
temp_stage_table
WHERE SOURCERECORD = 'SEADAB' AND AIRCRAFT_ROOT = 'B52';


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
        TGTCOUNTRY,
        RESULTSBDA,
        WEAPON_CLASS AS WEAPONTYPECLASS,
        RESULTSBDATYPE,
        MISSIONID,
        MFUNC_DESC,
        MFUNC_DESC_CLASS,
        PERIODOFDAY,
        SOURCERECORD,
        TGTTYPE,
        RELEASEALTITUDE,
        NUMWEAPONSDELIVERED,
        TGTCLOUDCOVER,
        TGTCONTROL
    FROM temp_stage_table
) 
TO 'THOR_Analysis.parquet'
(FORMAT 'parquet', COMPRESSION 'zstd');
