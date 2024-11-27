/*

Tableau SQL Queries
*/


SELECT 
	location, 
	SUM(CAST(new_deaths as int)) as TotalDeathCount
FROM covid_deaths
WHERE continent IS NULL 
	AND location NOT IN ('World', 'European Union', 'International')
GROUP BY location
ORDER BY TotalDeathCount DESC

-- Bar Chart Distribution by Continent


SELECT 
	Location, 
	Population, 
	MAX(total_cases) as HighestInfectionCount,  
	MAX((CAST(total_cases AS REAL) / CAST(Population AS REAL))) * 100 AS PercentPopulationInfected
FROM covid_deaths
GROUP BY 
	Location, 
	Population
ORDER BY PercentPopulationInfected DESC

-- Percentage of population infected

SELECT 
    SUM(new_cases) AS total_cases, 
    SUM(CAST(new_deaths AS INT)) AS total_deaths, 
    CAST(SUM(CAST(new_deaths AS INT)) AS REAL) / CAST(SUM(new_cases) AS REAL) * 100 AS DeathPercentage
FROM 
    covid_deaths
WHERE 
    continent IS NOT NULL 
ORDER BY 
    total_cases, total_deaths;

-- Global Numbers

SELECT 
    Location, 
    Population,
    date,
    MAX(total_cases) AS HighestInfectionCount,  
    MAX((CAST(total_cases AS REAL) / CAST(Population AS REAL)) * 100) AS PercentPopulationInfected
FROM covid_deaths
GROUP BY 
    Location, 
	Population, 
	date
ORDER BY 
    PercentPopulationInfected DESC;


-- Percentage of population infected timeline