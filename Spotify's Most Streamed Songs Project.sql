/*
The BPM Effect: Success Among Spotify’s Most-Streamed Songs  

Skills used: 
- **Joins**: Used to combine data from multiple rows within the same table (such as `self-joins`) and to merge data across tables with `INNER JOIN`. This was particularly useful for correlating multiple attributes (such as BPM and streaming metrics) for each song.
- **CTEs (Common Table Expressions)**: Implemented CTEs to simplify complex queries, such as categorizing songs into BPM ranges, calculating quartiles, and aggregating statistics. CTEs were also used for creating temporary views to segment data and perform ranking.
- **Window Functions**: Applied window functions like `RANK()` and `NTILE()` to calculate the ranking of songs based on streams and divide them into quartiles. This was also used for calculating percentiles and ranking within partitions to analyze engagement metrics.
- **Aggregate Functions**: Used aggregate functions like `AVG()`, `COUNT()`, `SUM()`, and `STDDEV()` to calculate key metrics such as average streams, the number of songs per category, and statistical variance across different groups (e.g., BPM ranges and performance quartiles).
- **Cross Joins**: Used `CROSS JOIN` to combine aggregate statistics (such as average BPM and streams) with song data, ensuring consistency when performing analysis across all tracks, regardless of groupings.
- **Conditional Aggregation**: Utilized `CASE` statements for conditional aggregation to categorize songs into performance buckets, such as high/low engagement based on specific criteria (streams, BPM, energy, etc.).
- **Percentile Calculations**: Employed `PERCENTILE_CONT()` to calculate percentiles and split songs into performance buckets. This was particularly useful for analyzing top-performing songs (e.g., top 25% in streams).
- **Correlation Functions**: Used `CORR()` to calculate the correlation between streaming performance and song attributes (such as BPM, energy, danceability, etc.) to identify significant relationships between song features and streaming success.
- **Z-Scores**: Calculated Z-scores for various song metrics (e.g., BPM, streams, energy) to detect outliers and standardize the data for comparison across different song characteristics.
- **Grouping and Segmentation**: Used grouping techniques and segmentation based on BPM ranges and performance quartiles to analyze the effects of different attributes on streaming success. This helped identify trends and patterns within specific categories.
- **Performance Buckets**: Created performance buckets (quartiles) based on streaming metrics using `NTILE()` for better insight into how songs perform relative to others in terms of engagement (streams, likes, comments, etc.).
- **Statistical Analysis**: While the Kruskal-Wallis test is not used in this project, statistical analysis techniques like calculating Z-scores and percentiles were crucial in evaluating song performance and detecting significant differences across groups.
- **Data Transformation**: Applied transformations for segmenting songs based on their attributes (e.g., grouping by BPM ranges) and for calculating summary statistics across multiple metrics. This enabled a more granular analysis of song attributes in relation to streaming performance.
*/

WITH bpm_ranges AS (
  SELECT 
    CASE 
      WHEN bpm BETWEEN 60 AND 80 THEN '60-80 bpm'
      WHEN bpm BETWEEN 80 AND 100 THEN '80-100 bpm'
      WHEN bpm BETWEEN 100 AND 120 THEN '100-120 bpm'
      WHEN bpm BETWEEN 120 AND 140 THEN '120-140 bpm'
      WHEN bpm BETWEEN 140 AND 160 THEN '140-160 bpm'
      ELSE '160+ bpm' 
    END AS bpm_range,
    AVG(streams) AS avg_streams,
    CASE 
      WHEN bpm BETWEEN 60 AND 80 THEN 1
      WHEN bpm BETWEEN 80 AND 100 THEN 2
      WHEN bpm BETWEEN 100 AND 120 THEN 3
      WHEN bpm BETWEEN 120 AND 140 THEN 4
      WHEN bpm BETWEEN 140 AND 160 THEN 5
      ELSE 6 
    END AS sort_order
  FROM spotify
  GROUP BY bpm_range, sort_order
)
SELECT *
FROM bpm_ranges
ORDER BY sort_order;



-- Obtain average streams by BPM (beats per minute) bucket



SELECT 
    CORR(bpm, streams) AS bpm_stream_correlation,
    CORR(energy_percent, streams) AS energy_stream_correlation,
    CORR(danceability_percent, streams) AS danceability_stream_correlation,
    CORR(valence_percent, streams) AS valence_stream_correlation,
    CORR(acousticness_percent, streams) AS acoustic_stream_correlation,
    CORR(liveness_percent, streams) AS liveness_stream_correlation,
    CORR(instrumentalness_percent, streams) AS instrumentalness_stream_correlation
FROM spotify;



-- Correlation between streams and distinct attributes of songs



WITH stream_percentiles AS (
    SELECT 
        track_name, 
        artist_name, 
        bpm,
        energy_percent,
        danceability_percent,
        valence_percent,
        acousticness_percent,
        liveness_percent,
        instrumentalness_percent,
        streams,
        NTILE(4) OVER (ORDER BY streams DESC) AS stream_quartile
    FROM spotify
)
SELECT 
    CASE 
        WHEN stream_quartile = 1 THEN 'Upper Quartile'
        WHEN stream_quartile = 2 THEN 'Second Interquartile Range'
        WHEN stream_quartile = 3 THEN 'Third Interquartile Range'
        WHEN stream_quartile = 4 THEN 'Lower Quartile'
    END AS stream_bucket,
    AVG(bpm) AS avg_bpm,
    AVG(energy_percent) AS avg_energy,
    AVG(danceability_percent) AS avg_danceability,
    AVG(valence_percent) AS avg_valence,
    AVG(acousticness_percent) AS avg_acousticness,
    AVG(liveness_percent) AS avg_liveness,
    AVG(instrumentalness_percent) AS avg_instrumentalness,
    AVG(streams) AS avg_streams
FROM stream_percentiles
GROUP BY stream_quartile
ORDER BY stream_quartile;



-- Segment streams into quartiles (performance)
-- Obtains the average of each attribute within a specific quartile  
-- Comapares variance of attributes across performance buckets



WITH bpm_grouped_artists AS (
  SELECT artist_name, 
         COUNT(DISTINCT bpm_range) AS bpm_bucket_count,
         AVG(streams) AS avg_streams
  FROM (
    SELECT artist_name, streams,
           CASE 
              WHEN bpm BETWEEN 60 AND 80 THEN '60-80 bpm'
              WHEN bpm BETWEEN 80 AND 100 THEN '80-100 bpm'
              WHEN bpm BETWEEN 100 AND 120 THEN '100-120 bpm'
              WHEN bpm BETWEEN 120 AND 140 THEN '120-140 bpm'
              WHEN bpm BETWEEN 140 AND 160 THEN '140-160 bpm'
              WHEN bpm > 160 THEN '160+ bpm'
           END AS bpm_range
    FROM spotify
  ) subquery
  GROUP BY artist_name
)
SELECT bpm_bucket_count, 
       AVG(avg_streams) AS avg_streams
FROM bpm_grouped_artists
GROUP BY bpm_bucket_count;



-- Shows the streams per the number of distinct BPM Ranges an artist uses
-- Obtians insights on versatility effectiveness



SELECT bpm, 
       streams, 
       energy_percent, 
       danceability_percent, 
       valence_percent, 
       instrumentalness_percent, 
       liveness_percent, 
       speechiness_percent, 
       track_name,
       artist_name,
       -- Adding absolute z-scores for each metric
       ABS((bpm - AVG(bpm) OVER ()) / STDDEV(bpm) OVER ()) AS bpm_abs_zscore,
       ABS((energy_percent - AVG(energy_percent) OVER ()) / STDDEV(energy_percent) OVER ()) AS energy_abs_zscore,
       ABS((danceability_percent - AVG(danceability_percent) OVER ()) / STDDEV(danceability_percent) OVER ()) AS danceability_abs_zscore,
       ABS((valence_percent - AVG(valence_percent) OVER ()) / STDDEV(valence_percent) OVER ()) AS valence_abs_zscore,
       ABS((instrumentalness_percent - AVG(instrumentalness_percent) OVER ()) / STDDEV(instrumentalness_percent) OVER ()) AS instrumentalness_abs_zscore,
       ABS((liveness_percent - AVG(liveness_percent) OVER ()) / STDDEV(liveness_percent) OVER ()) AS liveness_abs_zscore,
       ABS((speechiness_percent - AVG(speechiness_percent) OVER ()) / STDDEV(speechiness_percent) OVER ()) AS speechiness_abs_zscore
FROM spotify
WHERE bpm IS NOT NULL
AND energy_percent IS NOT NULL
AND danceability_percent IS NOT NULL
AND valence_percent IS NOT NULL
AND instrumentalness_percent IS NOT NULL
AND liveness_percent IS NOT NULL
AND speechiness_percent IS NOT NULL
ORDER BY streams;



-- Gives us easy access to spot outliers and analyze them based on their z-score



WITH artist_bpm_buckets AS (
  SELECT artist_name, 
         COUNT(DISTINCT bpm_range) AS bpm_bucket_count
  FROM (
    SELECT artist_name, 
           CASE 
              WHEN bpm BETWEEN 60 AND 80 THEN '60-80 bpm'
              WHEN bpm BETWEEN 80 AND 100 THEN '80-100 bpm'
              WHEN bpm BETWEEN 100 AND 120 THEN '100-120 bpm'
              WHEN bpm BETWEEN 120 AND 140 THEN '120-140 bpm'
              WHEN bpm BETWEEN 140 AND 160 THEN '140-160 bpm'
              WHEN bpm > 160 THEN '160+ bpm'
           END AS bpm_range
    FROM spotify
    GROUP BY artist_name, bpm
  ) subquery
  GROUP BY artist_name
),
stream_stats AS (
  SELECT AVG(streams) AS avg_streams, STDDEV(streams) AS stddev_streams,
         AVG(bpm) AS avg_bpm, STDDEV(bpm) AS stddev_bpm
  FROM spotify
),
outlier_tracks AS (
  SELECT artist_name, track_name, bpm, streams
  FROM spotify
  WHERE track_name IN ('Mejor Que Yo', 'Curtains', 'Mr. Morale', 'Worldwide Steppers', 'Crown', 
                       'POLARIS - Remix', 'TULUM', 'Auntie Diaries', 'Dawn FM', 
                       'What Was I Made For? [From The Motion Picture "Barbie"]', 'SPACE MAN')
)
SELECT o.artist_name, o.track_name, o.bpm, o.streams, a.bpm_bucket_count,
       (o.streams - s.avg_streams) / s.stddev_streams AS z_score_streams,
       (o.bpm - s.avg_bpm) / s.stddev_bpm AS z_score_bpm
FROM outlier_tracks o
JOIN artist_bpm_buckets a
  ON o.artist_name = a.artist_name
CROSS JOIN stream_stats s
ORDER BY bpm ASC;



-- Analyze outliers that posses a BMP z-score > [1.5] searching them by their specific name
-- Visualization of results reinforces previous insights and analysis
