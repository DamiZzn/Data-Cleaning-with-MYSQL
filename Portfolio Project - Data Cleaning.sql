-- DATA CLEANING

SELECT * 
FROM layoffs
LIMIT 10;


-- first  we create a copy of the table because we should not work on the raw data
CREATE TABLE layoffs_staging
LIKE layoffs;

SELECt * FROM layoffs_staging;

-- fill the table layoffs_staging with the values
INSERT layoffs_staging
SELECT * FROM layoffs;

-- now when we are data cleaning we usually follow a few steps
-- 1. check for duplicates and remove any
-- 2. standardize data and fix errors
-- 3. Look at null values and see what 
-- 4. remove any columns and rows that are not necessary - few ways


-- 1. REMOVE DUPLICATES

# First let's check for duplicates

SELECT *, 
ROW_NUMBER() OVER(PARTITION BY company, industry, total_laid_off, 'date') AS row_num
FROM layoffs_staging;

WITH duplicate_cte AS
( SELECT *, 
ROW_NUMBER() OVER(PARTITION BY company, industry, total_laid_off, 'date') AS row_num
FROM layoffs_staging
)

SELECT * 
FROM duplicate_cte 
WHERE row_num > 1;

-- let's look at Oda to comfirm
SELECT * 
FROM layoffs_staging 
WHERE company = 'Oda';

-- it looks like these are all legitimate entries and shouldn't be deleted. We need to really look at every single row to be accurate

-- these are our real duplicates
SELECT *
FROM (
	SELECT company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions,
		ROW_NUMBER() OVER (
			PARTITION BY company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions
			) AS row_num
	FROM 
		layoffs_staging
) duplicates
WHERE 
	row_num > 1;
    
-- OR
WITH duplicate_cte AS
( 
SELECT *, 
ROW_NUMBER() OVER(
	PARTITION BY company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions
			) AS row_num
FROM layoffs_staging
)

SELECT * 
FROM layoffs_staging 
WHERE company = 'Casper'; 

CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
   `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO layoffs_staging2
SELECT *, 
ROW_NUMBER() OVER(
	PARTITION BY company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions
			) AS row_num
FROM layoffs_staging;

DELETE 
FROM layoffs_staging2
WHERE row_num > 1; 

SELECT * 
FROM layoffs_staging2; 



-- 2. STANDARDIZE DATA

-- the trim function will take off the white space
SELECT company, TRIM(company) 
FROM layoffs_staging2; 

UPDATE layoffs_staging2
SET company = TRIM(company);

-- we notice The Crypto has multiple different variations. We need to standardize that - let's say all to Crypto
SELECT distinct(industry)
FROM layoffs_staging2
ORDER BY 1; 

SELECT *
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%' ; 

UPDATE layoffs_staging2
SET industry = 'Crypto' 
WHERE industry LIKE 'Crypto%';

-- let's take a look at these
SELECT *
FROM layoffs_staging2
WHERE company LIKE 'Bally%';
-- nothing wrong here
SELECT *
FROM layoffs_staging2
WHERE company LIKE 'airbnb%';

-- it looks like airbnb is a travel, but this one just isn't populated.
-- I'm sure it's the same for the others. What we can do is
-- write a query that if there is another row with the same company name, it will update it to the non-null industry values
-- makes it easy so if there were thousands we wouldn't have to manually check them all

-- we should set the blanks to nulls since those are typically easier to work with
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL OR industry = ''; 

UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

-- now we need to populate those nulls if possible
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

-- and if we check it looks like Bally's was the only one without a populated row to populate this null values
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL 
OR industry = ''
ORDER BY industry;

-- now let's look at country
SELECT DISTINCT country
FROM layoffs_staging2
ORDER BY 1;

-- The SQL function trim(trailing from …) removes space characters from the end (right side) of a string.
UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country);

-- now if we run this again it is fixed
SELECT DISTINCT country
FROM world_layoffs.layoffs_staging2
ORDER BY country;

-- Let's also fix the date columns:
SELECT `date`,
STR_TO_DATE(`date`, '%m/%d/%Y')
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- now we can convert the data type properly
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- 3. Look at Null Values
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- Delete Useless data we can't really use
DELETE FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

SELECT * 
FROM layoffs_staging2;

ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

SELECT * 
FROM layoffs_staging2;