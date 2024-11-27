/*
The TikTok Playbook: Cracking the Code to Viral Engagement 

Skills used: 
- **Joins**: Used for combining data from multiple rows within the same table (`self-join`), and for combining data across tables using `INNER JOIN`.
- **CTEs (Common Table Expressions)**: Implemented to simplify complex queries and calculations such as aggregating data, segmenting by video duration, and calculating statistics.
- **Window Functions**: Applied `RANK()` and `PERCENTILE_CONT()` for ranking video engagement metrics and calculating percentiles within partitions.
- **Aggregate Functions**: Used `SUM()`, `COUNT()`, and `AVG()` to calculate metrics like sum of ranks, group sizes, and video counts across specific conditions.
- **Creating Views**: Employed temporary views using CTEs to organize data into segments such as engagement categories and rank statistics.
- **Converting Data Types**: Applied necessary conversions when dealing with hardcoded values and transformations for statistical formulas like Kruskal-Wallis.
- **Cross Joins**: Used `CROSS JOIN` for combining fixed results from hardcoded tables (e.g., rank statistics) with dynamic data.
- **Percentile Calculations**: Used `PERCENTILE_CONT()` for calculating thresholds to segment engagement metrics (views, likes, shares, comments) into high and low categories.
- **Advanced Statistical Functions**: Implemented advanced statistical analysis with the Kruskal-Wallis test to calculate H-statistics.
- **Dynamic Case Statements**: Utilized `CASE` for conditional aggregation and segmentation, such as categorizing engagement as 'High' or 'Low' based on video metrics.
*/

SELECT
    COUNT(*) AS count,
    video_like_count AS like_count
FROM titkok_videos
GROUP BY video_like_count
ORDER BY like_count;

SELECT
    COUNT(*) AS count,
    video_share_count AS share_count
FROM titkok_videos
GROUP BY video_share_count
ORDER BY share_count;

SELECT
    COUNT(*) AS count,
    video_view_count AS view_count
FROM titkok_videos
GROUP BY video_view_count
ORDER BY view_count;

SELECT
    COUNT(*) AS count,
    video_comment_count AS comment_count
FROM titkok_videos
GROUP BY video_comment_count
ORDER BY comment_count;

-- Obtain histograms to analyze distribution

WITH categorized_videos AS (
    SELECT *,
    CASE 
        WHEN video_duration_seconds <= 10 THEN '0-10 sec'
        WHEN video_duration_seconds BETWEEN 11 AND 30 THEN '11-30 sec'
        WHEN video_duration_seconds BETWEEN 31 AND 60 THEN '31-60 sec'
    END AS video_length_category
    FROM tiktok_videos
)
SELECT video_length_category,
       video_view_count,
       video_like_count,
       video_share_count,
       video_comment_count
FROM categorized_videos
ORDER BY video_length_category;


-- Segmentation of key performance metrics by bucket length

WITH categorized_videos AS (
    SELECT *,
        CASE 
            WHEN video_duration_seconds <= 10 THEN '0-10 sec'
            WHEN video_duration_seconds BETWEEN 11 AND 30 THEN '11-30 sec'
            WHEN video_duration_seconds BETWEEN 31 AND 60 THEN '31-60 sec'
        END AS video_length_category
    FROM tiktok_videos
),
ranked_videos AS (
    SELECT video_length_category,
           video_view_count,
           RANK() OVER (ORDER BY video_view_count ASC) AS view_rank
    FROM categorized_videos
),
grouped_ranks AS (
    SELECT 
        video_length_category,
        SUM(view_rank) AS sum_of_ranks,
        COUNT(*) AS group_size
    FROM ranked_videos
    GROUP BY video_length_category
),
total_count AS (
    SELECT COUNT(*) AS total_videos
    FROM tiktok_videos
    WHERE video_duration_seconds <= 60
)
SELECT 
    g.video_length_category,
    g.sum_of_ranks,
    g.group_size,
    t.total_videos,
    (g.sum_of_ranks * g.sum_of_ranks) / g.group_size AS rank_squared_over_size
FROM grouped_ranks g, total_count t;


-- Set up for Kruskal–Wallis test
-- Calculates sum_of_ranks^2 / group_size for each group --> Needed for H-statistic formula 
-- Will be hard coding some results from this query in the following ones (be advised)

WITH rank_stats AS (
    SELECT '0-10 sec' AS video_length_category, 182229908668.3583 AS rank_squared_over_size, 2099 AS group_size
    UNION ALL
    SELECT '11-30 sec', 628897365263.25, 6783
    UNION ALL
    SELECT '31-60 sec', 926445703390.3441, 10201
),

total_videos AS (
    SELECT 19083 AS total_videos -- Hard coded total amount of videos being analyzed
),

kruskal_wallis_calculation AS (
    SELECT 
        SUM(rank_squared_over_size) AS sum_of_rank_squared_over_size, 
        tv.total_videos 
    FROM rank_stats rs
    CROSS JOIN total_videos tv
    GROUP BY tv.total_videos


-- Gives H Statistic Value
-- H-Statistic = 2.3175

WITH Thresholds AS (
    SELECT 
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY video_view_count) AS high_view_threshold,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY video_like_count) AS high_like_threshold,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY video_share_count) AS high_share_threshold,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY video_comment_count) AS high_comment_threshold
    FROM 
        tiktok_videos
), Engagement_Counts AS (
    SELECT 
        verified_status,
        CASE 
            WHEN video_view_count > (SELECT high_view_threshold FROM Thresholds) THEN 'High'
            ELSE 'Low'
        END AS view_engagement,
        CASE 
            WHEN video_like_count > (SELECT high_like_threshold FROM Thresholds) THEN 'High'
            ELSE 'Low'
        END AS like_engagement,
        CASE 
            WHEN video_share_count > (SELECT high_share_threshold FROM Thresholds) THEN 'High'
            ELSE 'Low'
        END AS share_engagement,
        CASE 
            WHEN video_comment_count > (SELECT high_comment_threshold FROM Thresholds) THEN 'High'
            ELSE 'Low'
        END AS comment_engagement
    FROM 
        tiktok_videos,
        Thresholds
)
SELECT 
    verified_status,
    view_engagement,
    COUNT(*) AS count
FROM 
    Engagement_Counts
GROUP BY 
    verified_status, view_engagement;


-- Engagement Differences Across Verfied vs. Not Verified Accounts
-- Considers High Performing = Top 25% percentile in at least one performance category (likes, views, comments, shares)
