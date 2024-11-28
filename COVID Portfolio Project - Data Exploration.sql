/*

Covid 19 Data Exploration -- DATA AS OF MARCH 2021

Skills Used:
- Joins: Combining data from different tables using inner joins.
- CTEs (Common Table Expressions): Used for complex queries to simplify them into manageable parts.
- Temp Tables: Temporary tables to hold interim results for complex calculations.
- Windows Functions: Used for calculations across a set of table rows that are somehow related to the current row.
- Aggregate Functions: To perform calculations on a set of values and return a single value.
- Creating Views: To store the SQL statement for the view so it can be reused.
- Converting Data Types: Ensuring correct data type for calculations and storage.
- Data Analysis: Analyzing data through various SQL queries to derive meaningful insights.
*/

SELECT *
FROM covid_deaths
WHERE continent IS NOT NULL 
order by 3,4

-- Data we're starting with


SELECT 
	Location, 
	date, 
	total_cases, 
	new_cases, 
	total_deaths, 
	population
FROM covid_deaths
WHERE continent IS NOT NULL 
ORDER BY 1,2

-- Total Cases vs Total Deaths
-- Likelihood of dying of COVID if if countracted in your country


SELECT 
	Location, 
	date, 
	total_cases,
	total_deaths, 
	(CAST(total_deaths AS REAL) / CAST(total_cases AS REAL)) * 100 AS DeathPercentage
FROM covid_deaths
WHERE location LIKE '%states%'
	AND continent IS NOT NULL 
ORDER BY 1,2

-- Total Cases vs Population (US)
-- Shows what percentage of population infected with Covid


SELECT 
	Location
	date, 
	Population, 
	total_cases,  
	(CAST(total_cases AS REAL) / CAST(Population AS REAL)) * 100 AS PercentPopulationInfected
FROM covid_deaths
ORDER BY 1,2

-- Countries with Highest Infection Rate compared to Population


SELECT
	Location, 
	Population, 
	MAX(total_cases) as HighestInfectionCount,  
	MAX((CAST(total_cases AS REAL) / CAST(Population AS REAL)) * 100) AS PercentPopulationInfected
FROM covid_deaths
GROUP BY
	Location, 
	Population
ORDER BY PercentPopulationInfected DESC

-- Countries with Highest Death Count per Population


SELECT 
	Location, 
	MAX(cast(Total_deaths as int)) as TotalDeathCount
FROM covid_deaths
WHERE continent IS NOT NULL 
GROUP BY Location
ORDER BY TotalDeathCount DESC

-- BREAKING THINGS DOWN BY CONTINENT
-- Showing contintents with the highest death count per population


SELECT 
	continent, 
	MAX(cast(Total_deaths as int)) as TotalDeathCount
FROM covid_deaths
WHERE continent IS NOT NULL 
GROUP BY continent
ORDER BY TotalDeathCount DESC

-- GLOBAL NUMBERS


SELECT 
	SUM(new_cases) as total_cases, 
	SUM(cast(new_deaths as int)) as total_deaths, 
	(CAST(SUM(CAST(new_deaths AS INT)) AS REAL) / CAST(SUM(new_cases) AS REAL)) * 100 AS DeathPercentage
FROM covid_deaths
WHERE continent IS NOT NULL 
ORDER BY 1,2

-- Total Population vs Vaccinations
-- Shows Percentage of Population with at least one Covid Vaccine


SELECT 
	d.continent, 
	d.location, 
	d.date, 
	d.population, 
	v.new_vaccinations, 
	COALESCE(SUM(CAST(v.new_vaccinations AS INT)) 
        OVER (PARTITION BY d.location 
        ORDER BY d.date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 0) AS RollingPeopleVaccinated
FROM covid_deaths d
JOIN covid_data v
	ON d.location = v.location
	AND d.date = v.date
WHERE d.continent IS NOT NULL 
ORDER BY 2,3

-- CTE to perform calculation on Partition By in previous query


WITH PopvsVac AS (
    SELECT 
        d.continent, 
        d.location, 
        d.date, 
        d.population, 
        v.new_vaccinations,
        COALESCE(SUM(CAST(v.new_vaccinations AS INT))
            OVER (PARTITION BY d.location 
                  ORDER BY d.date
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 0) AS RollingPeopleVaccinated
    FROM covid_deaths d
    JOIN covid_data v
        ON d.location = v.location
        AND d.date = v.date
    WHERE d.continent IS NOT NULL
)
SELECT 
    Continent,
    Location,
    Date,
    Population,
    New_Vaccinations,
    RollingPeopleVaccinated,
    (CAST(RollingPeopleVaccinated AS REAL) / CAST(Population AS REAL)) * 100 AS PercentPopulationVaccinated
FROM PopvsVac
ORDER BY Location, Date;


-- Temp Table to perform Calculation on Partition By in previous query


-- Drop the temporary table if it exists
IF OBJECT_ID('tempdb..#PercentPopulationVaccinated') IS NOT NULL
    DROP TABLE #PercentPopulationVaccinated;

-- Create a new temporary table
CREATE TABLE #PercentPopulationVaccinated
(
    Continent NVARCHAR(255),
    Location NVARCHAR(255),
    Date DATETIME,
    Population NUMERIC,
    New_Vaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
);

-- Insert data into the temporary table
INSERT INTO #PercentPopulationVaccinated
SELECT 
    d.continent, 
    d.location, 
    d.date, 
    d.population, 
    v.new_vaccinations, 
    SUM(CAST(v.new_vaccinations AS INT)) 
        OVER (PARTITION BY d.location 
              ORDER BY d.date) AS RollingPeopleVaccinated
FROM covid_deaths d
JOIN covid_data v
    ON d.location = v.location
    AND d.date = v.date;

-- Select data from the temporary table
SELECT 
    *,
    (CAST(RollingPeopleVaccinated AS FLOAT) / CAST(Population AS FLOAT)) * 100 AS PercentPopulationVaccinated
FROM #PercentPopulationVaccinated
ORDER BY Location, Date;

-- View to store data for visualizations



