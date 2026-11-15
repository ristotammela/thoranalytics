SET variable input_path  = 'THOR_Vietnam_Bombing_Operations.parquet';



CREATE TEMP TABLE temp_stage_table AS
SELECT  
        *
FROM read_parquet(getvariable('input_path'));

COPY (
    SELECT distinct TGTTYPE FROM temp_stage_table ORDER BY TGTTYPE
) to 'TGTTYPE_distinct.csv' (HEADER, DELIMITER ',');