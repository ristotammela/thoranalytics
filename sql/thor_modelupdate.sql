SET preserve_insertion_order = false;

SET variable input_path  = 'THOR_Analysis.parquet';

CREATE TEMP TABLE temp_predictions AS
SELECT *
FROM read_csv('predictions\*.csv', header = true, union_by_name = true);

CREATE TEMP TABLE temp_imint_predictions (
    THOR_DATA_VIET_ID BIGINT PRIMARY KEY,
    predicted_ishochiminhtrailoperation BIGINT NOT NULL
        CHECK (predicted_ishochiminhtrailoperation IN (0, 1))
);

INSERT INTO temp_imint_predictions
SELECT THOR_DATA_VIET_ID, predicted_ishochiminhtrailoperation
FROM read_csv(
    'predictions\THOR_IMINT_hochiminhtrail_predictions.csv',
    header = true,
    types = {
        'THOR_DATA_VIET_ID': 'BIGINT',
        'predicted_ishochiminhtrailoperation': 'BIGINT'
    }
);

CREATE TEMP TABLE temp_analysis AS
SELECT * FROM read_parquet(getvariable('input_path'));

SELECT CASE WHEN EXISTS (
    SELECT 1
    FROM temp_imint_predictions AS predictions
    WHERE NOT EXISTS (
        SELECT 1 FROM temp_analysis AS analysis
        WHERE analysis.THOR_DATA_VIET_ID = predictions.THOR_DATA_VIET_ID
    )
) THEN error('Prediction CSV contains keys missing from THOR_Analysis.parquet')
END;

ALTER TABLE temp_analysis
ADD COLUMN IF NOT EXISTS predicted_ishochiminhtrailoperation BIGINT;

UPDATE temp_analysis SET predicted_ishochiminhtrailoperation = NULL;

UPDATE temp_analysis
SET predicted_ishochiminhtrailoperation = predictions.predicted_ishochiminhtrailoperation
FROM temp_imint_predictions AS predictions
WHERE temp_analysis.THOR_DATA_VIET_ID = predictions.THOR_DATA_VIET_ID;

COPY temp_analysis TO (getvariable('input_path'))
    (FORMAT parquet, COMPRESSION zstd, USE_TMP_FILE true);
