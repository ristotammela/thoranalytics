SET preserve_insertion_order = false;

SET variable input_path  = 'THOR_Vietnam_Bombing_Operations_geocoded.parquet';

## Extract base values from the input Parquet file

CREATE TEMP TABLE temp_stage_table AS
SELECT  
        *,
        CASE 
            WHEN OPERATIONSUPPORTED ILIKE '%BARREL ROLL%' THEN 'BARREL ROLL'
            WHEN OPERATIONSUPPORTED ILIKE '%STEEL TIGER%' THEN 'STEEL TIGER'
            WHEN OPERATIONSUPPORTED ILIKE '%TIGER HOUND%' THEN 'TIGER HOUND'
            WHEN OPERATIONSUPPORTED ILIKE '%IGLOO WHITE%' THEN 'IGLOO WHITE'
            WHEN OPERATIONSUPPORTED ILIKE '%YANKEE TEIM%' THEN 'YANKEE TEAM'
            ELSE NULL
        END AS operationhochiminhtrail,
        CASE 
            WHEN OPERATIONSUPPORTED ILIKE '%IN COUNTRY%'   THEN 'IN COUNTRY'
            WHEN OPERATIONSUPPORTED ILIKE '%ROLLING THUN%' THEN 'ROLLING THUNDER'
            ELSE NULL
        END AS operationother,
        try_strptime(MSNDATE, ['%Y-%m-%d', '%Y%m%d'])::DATE AS missiondate,
        'UNDEFINED' AS WEAPON_CLASS,
        'UNDEFINED' AS RESULTSBDATYPE,
        'UNDEFINED' AS targetcategory,
        'UNDEFINED' AS AIRCRAFT_APPLICATION,
        FALSE AS IMINT,
        FALSE AS SIGINT,
        GEOCODE_COUNTRY_CODE,
        missiondate - MIN(missiondate) OVER () AS missiondate_day
FROM read_parquet(getvariable('input_path'));

## Map weapon types to weapon classes

CREATE TEMP TABLE map_weapons AS
SELECT *
FROM read_csv_auto(
    'THOR_Vietnam_Weapons_Glossary.csv',
    header = true,
    encoding = 'latin-1'
);

CREATE TEMP TABLE map_aircraft AS
SELECT *
FROM read_csv_auto(
    'THOR_Vietnam_Aircraft_Glossary.csv',
    header = true,
    encoding = 'latin-1'
);


UPDATE temp_stage_table
SET WEAPON_CLASS = map_weapons.WEAPON_CLASS
FROM map_weapons
WHERE temp_stage_table.WEAPONTYPE = map_weapons.WEAPONTYPE;


UPDATE temp_stage_table
SET AIRCRAFT_APPLICATION = map_aircraft.AIRCRAFT_APPLICATION
FROM map_aircraft
WHERE temp_stage_table.VALID_AIRCRAFT_ROOT = map_aircraft.VALIDATED_ROOT;


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


# remove coordinates which are not in Vietnam, Cambodia or Laos

DELETE FROM temp_stage_table
WHERE GEOCODE_COUNTRY_CODE NOT IN ('VN', 'KH', 'LA');


# remove SEADAB B-52 records

DELETE FROM
temp_stage_table
WHERE SOURCERECORD = 'SEADAB' AND AIRCRAFT_ROOT = 'B52';




-- 1. Recreate the classification macro with all aircraft grouped under Air Defense & Radar
CREATE OR REPLACE MACRO classify_tgttype(val) AS (
    CASE
        -- 1. Ground Forces, Artillery & Camps
        WHEN TRIM(UPPER(val)) IN (
            '105MM GUN SITE', '122MM GUN SITE', '130MM GUN SITE', '155MM GUN SITE',
            '175MM GUN SITE', 'ARTILLERY', 'BASE', 'BASE CAMP AREA', 'BIVOUAC',
            'BIVOUAC\STORE AREA', 'BIVUOAC AREA', 'BNKR\TRENCH\ETC', 'BRKS BLDG',
            'BUNKER', 'CAMP', 'CAVE', 'CAVES', 'CIV POPULATN CENTR', 'CIV\DEF\STOR',
            'COASTAL DEFENSE SITE', 'DEFENSE STRUCTURE', 'FIREBASE', 'FOX HOLES',
            'FRTFD AREA', 'HIGHER\REVETMENTS', 'HUTS', 'MACHINE GUN (ANY)',
            'MIL AREA', 'MIL BRKS\ADMIN SPT', 'MILITARY COMPLEX', 'MINEFIELD (LAND)',
            'MNFLD LAND', 'MORTAR SITE', 'PERSONNEL\ANY', '"RCKT LNCHR (B40, ETC)"',
            'REVETMENT', 'ROCKET SITE', 'SNIPER', 'STAGE AREA', 'STAGING AREA',
            'STRONG POINT', 'TOWER', 'TOWER\OUTPST\LKOUT', 'TRENCH', 'TRENCHES',
            'TROOP BATT', 'TROOP DIV', 'TROOP REGT', 'TROOP UNK', '"TROOP UNK #"',
            'TROOPS', 'TROOPS IN CONTACT', 'TUNNEL', 'TUNNELS', 'VILLAGE',
            'WAY STA\REST AREA', 'WEAPONS\ANY'
        ) THEN 'Ground Forces, Artillery & Camps'

        -- 2. Air Defense & Radar (Now includes all aircraft & MiGs)
        WHEN TRIM(UPPER(val)) IN (
            '100MM GUN SITE', '12.7 GUN SITE', '14.5MM GUN SITE', '23MM GUN SITE',
            '57MM GUN SITE', '85MM GUN SITE', 'AA SITE', 'AAA SITE UND',
            'AAA SITE UNK CAL', 'AAA\37MM  CR MORE', 'AIRCRAFT (UNIDENT)',
            'AIRCRAFT ON GROUND', 'AIRCRAFT TRANSPORT', 'ANTI-AIRCRAFT',
            'AUTO WEAPONS\ZPU', 'DOWNED AIRCRAFT', 'FIGHTER', 'HELICOPTER',
            'HH SAM SA\7', 'LAUNCHER (MISSILE)', 'MIG17', 'MIG19', 'MIG21',
            'MIG21 ON GND', 'MISSILE', 'MISSILE TRANSPORTER', 'NBR OF AAA PIECES',
            'RADAR', 'RADAR SITE', 'RADAR SRCH INTERCP', 'RADAR VAN', 'SA SITE',
            'SAM CANISTER', 'SAM LAUNCHER\EQMT', 'SAM OXIDIZER', 'SAM SITE',
            'SA\3 SITE', 'SEARCHLIGHT', 'SILO'
        ) THEN 'Air Defense & Radar'

        -- 3. Vehicles & Armor
        WHEN TRIM(UPPER(val)) IN (
            'ARMORED VEHICLE', 'BICYCLE\SCOOTER', 'BULLDOZER', 'COMMUNICATIONS VAN',
            'CONSTRUCTION VEHICLES', 'DECOY MOVER PLUS ANY', 'MILITARY VEHICLES',
            'MOTOR VEHICLE', 'MOVERS\ANY', 'OX-CART', 'PACK ANIMALS', 'TANK',
            'TANK MV', 'TANK PARK', 'TRACKED VEHICLE', 'TRANSPORT',
            'TRANSPORT\TRK\TRLR', 'TRK\PRK\STORE AREA', 'TRUCK', 'TRUCK PARK',
            'TRUCK PARK\STOP', 'TRUCK PRK ST', 'TRUCK PRK\ST', 'TRUCKS', 'VAN'
        ) THEN 'Vehicles & Armor'

        -- 4. Roads, Bridges & Rail
        WHEN TRIM(UPPER(val)) IN (
            'BRDG', 'BRIDGE', 'BRIDGES', 'BRIDGE\ANY', 'CAUSEWAY', 'CHOKE POINT',
            'FOOT BRIDGE', 'FORD', 'FORDS\SUBSURFACE BRIDGE', 'INFILTRATION ROUTE',
            'LIGHTS ON ROAD', '"LOCOMT,RAIL VEH"', 'MOUNTAIN PASS', 'PONTOON BRIDGE',
            'RAIL LINES\ANY', 'RAILROAD', 'RAILROAD BRIDGE', 'RAILROAD COMPLEX',
            'RAILROAD CROSSING', 'RAILROAD SIDING', 'RAILROAD STA\TERM',
            'RAILROAD TRACK', 'RAILROAD VEHICLES', 'RAILROAD YARDS', 'ROAD',
            'ROAD CONST MATERIAL', 'ROADS\HIGHWAYS', 'ROAD\HIWAY\APPRCH',
            'ROLLING STOCK', 'RR TUNNEL', 'SEGMENT\TRANS ROUTE', 'TRAILS',
            'TRAIN CAR ANY'
        ) THEN 'Roads, Bridges & Rail'

        -- 5. Watercraft & Ports
        WHEN TRIM(UPPER(val)) IN (
            'ANCHORAGE', 'BOATS\BARGES', 'CANAL', 'CAUSEWAY\DAM', 'DAM', 'DIKE',
            'DRY DOCK', 'FERRY', 'FERRY CROSSING', 'FLOATING BAGS\BOXES', 'GUNBOAT',
            'ISLAND', 'JUNK  OR 1 WBLC', 'LEVEE', 'LOCK', 'MARINE RAILWAY',
            'MINEFIELD (SEA)', 'NAVAL BASE', 'NAVAL SUPPORT FACILITY', 'PIER',
            'PORT FACILITY', 'SAMPANS', 'SHIP', 'SHIPYARD', 'WATER INTERDICT PT',
            'WATER VEHICLES', 'WATERCRAFT', 'WATERWAY', 'WHARF'
        ) THEN 'Watercraft & Ports'

        -- 6. Supply, Ammo & Fuel (POL)
        WHEN TRIM(UPPER(val)) IN (
            'AMMO AREA', 'AMMO BLDG', 'AMMO STORAGE\DUMP', 'AMO\POL\SUP\CRT',
            'AREA\DEPOT', 'BUNKER FACILITY (POL)', 'CAVE STORAGE',
            'CRATE\STORAGE CONT', 'DRUM', 'DRUM (POL)', 'LOGISTICS\ANY',
            'OPEN STORAGE\DUMP', 'ORD AREA', 'PIPELINE', 'POL BARRELS', 'POL STORAGE',
            'POL TANKS', 'POL\TNK AREA', 'PUMPING STATION', 'REFINERY (POL)',
            '"REFINERY, ANY"', '"REFINERY, OIL\GAS"', 'STOR BLDG', 'STORAGE AREA',
            'SUPPLIES (MISCELL.)', 'SUPPLIES\RICE\WEAPONS', 'SUPPLY AREA',
            'SUPPLY STORAGE\DMPS', 'TANK (POL)', 'TNK POL', 'TRANS PT',
            'TRANSHIPMENT POINT', 'TRANSSHIP POINT', 'WAREHOUSE'
        ) THEN 'Supply, Ammo & Fuel (POL)'

        -- 7. Command & Infrastructure (Retains airfields, runways, and LZs)
        WHEN TRIM(UPPER(val)) IN (
            'AGRICULTURAL AREA', 'AIRFIELD', 'AIRFIELD\ANY TYPE', 'AIRFLD\ACRFT\ETC',
            'ANTENNA', 'ANTENNA\RADIO', 'BLDG', 'BUILDINGS', 'CCC\HQ\RADAR\ETC',
            'COMD CONTROL CENTR', 'COMM AREA', 'COMMAND POST', 'COMMUNICATIONS',
            'COMMUNICATIONS\ANY', 'CONSTRUCTION SITE', 'COOLING TOWERS', 'CP',
            'ELEC. PWR. FAC.', 'FACTORY INDUSTRIAL', '"FACTORY,ANY"', 'HQ COMPLEX',
            'HQS AREA', 'HYDROELEC PWR PLT', 'LANDING ZONE CONST',
            'LANDING ZONE PREP', 'PLANT', 'RADIO', 'RADIO COMM ANY\ANT',
            'RADIO COMMUNICATN', 'REPAIR YARD (UNIDENT)', 'RUNWAY',
            'THERMAL POWER PLANT'
        ) THEN 'Command & Infrastructure'

        -- 8. Area, Unidentified & Other
        WHEN TRIM(UPPER(val)) IN (
            'AREA', 'AREA COMPLEX', 'ASE         S', 'AUWP', 'CONFIRM ENEMY LOC',
            'INTERDICTION POINT', 'MEAN PT OF IMPACT', 'MERCURY GRASS SITE',
            'MINEABLE AREA', 'NO TARGET ACQUIRED', 'PRE-STRIKE', 'RPTD ENEMY LOC',
            'SENSOR FIELD', 'SSH', 'SUSP ENEMY LOC', 'TFA TARGET',
            'TRELLIS-CAMOUFLAGE', 'UNKNOWN\UNIDENTIFIED', 'UNK\UND'
        ) THEN 'Area, Unidentified & Other'

        ELSE 'Area, Unidentified & Other'
    END
);

-- 2. Refresh the targetcategory column on your existing table
UPDATE temp_stage_table
SET targetcategory = classify_tgttype(TGTTYPE);


UPDATE temp_stage_table
SET IMINT = TRUE
WHERE AIRCRAFT_ROOT in ('RA3', 'RA5', 'RB57','RF101','RF4','RF8');
    

UPDATE temp_stage_table
SET SIGINT = TRUE
WHERE AIRCRAFT_ROOT in ('RF66','RC47');


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
        TGTCONTROL,
        targetcategory,
        AIRCRAFT_APPLICATION,
        IMINT,
        SIGINT,
        operationother,
        GEOCODE_COUNTRY_CODE,
        missiondate_day
    FROM temp_stage_table
) 
TO 'THOR_Analysis.parquet'
(FORMAT 'parquet', COMPRESSION 'zstd');
