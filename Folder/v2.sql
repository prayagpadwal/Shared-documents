﻿
DECLARE @WeekFilter INT;
DECLARE @ActualsFilter DATE;
DECLARE @RAG_MIN_Threshold DECIMAL(6,2);
DECLARE @RAG_MAX_Threshold DECIMAL(6,2);
DECLARE @Output VARCHAR(40);
DECLARE @Year INT;

SET @WeekFilter = 38
SET @ActualsFilter = '2024-09-28'
SET @RAG_MIN_Threshold = .995;
SET @RAG_MAX_Threshold = 1.25;
SET @Output = 'PDC';
SET @YEAR = 2024;


/*
SELECT DISTINCT [FULL Week Number],[month],[Date Range]
FROM  bsa.dbo.vw_DOT_2024_PDC_Program_Data
WHERE [FULL Week Number] = 30
*/

--This CTE normalizes the notifications from our vw_WPML for just the YEAR we declared

WITH WPML_Actuals AS (

      SELECT      [PDC Program] AS [PDC Program]
                  ,[Notification]
                  ,[Order]
                  ,[MAT]
                  ,[Region]
                  ,[Div]
                  ,[Authorized Funding Action (2024)]
                  ,[Project Reporting Year]
                  ,[Work Plan Date]
                  ,[Report Date]
                  ,[Reference Date]
                  ,[Notif Status]
                  ,[Notif User Status]

      ---- INITIATION ----
                  ,SUM(
                        CASE
                              WHEN [Project Reporting Year] = @Year  THEN [Initiation Actuals]
                              ELSE 0
                        END) AS [Initiation Actuals]
                  ,[Initiation Out]
            
      ---- DESIGN ----
                  ,SUM(
                        CASE
                              WHEN [Project Reporting Year] = @Year  THEN [Design Actuals]
                              ELSE 0
                        END) AS [Design Actuals]
                  ,[Design Out]

      ---- DEPENDENCY ----
                  ,SUM(
                        CASE
                              WHEN [Project Reporting Year] = @Year  THEN [Dependency Actuals]
                              ELSE 0
                        END) AS [Dependency Actuals]
                  ,[Dependency Out]

      ---- SCHEDULE ----
                  /*,SUM(
                        CASE
                              WHEN [Project Reporting Year] = 2024  
                                    THEN [Schedule Actuals]
                              ELSE 0
                        END) AS [Schedule Actuals]*/

                  ,SUM(CASE
                              WHEN  (     
                                                CAST([CLICK End Date] AS DATE) <=  DATEADD(WEEK,8,CAST(@ActualsFilter AS DATE)) -- +8 WEEKS OUT
                                                OR (YEAR([Report Date]) = @Year)
                                          )
                                          AND [PDC Program] NOT IN ('ED Pole Repl', 'ED Pole Repl - Emergent'
                                                                                                ,'Maintenance Capital','Maintenance Expense'
                                                                                                ,'COE Capital','COE Expense')
                                          AND [Project Reporting Year] = @Year
                                    THEN  [Schedule Actuals]
                              WHEN  (     
                                                CAST([CLICK End Date] AS DATE) <= DATEADD(WEEK,8,CAST(@ActualsFilter AS DATE)) -- +8 WEEKS OUT
                                                OR (YEAR([Reference Date]) = @Year AND [Notif Status] = 'COMP')
                                          )
                                          AND [PDC Program] IN ('ED Pole Repl', 'ED Pole Repl - Emergent'
                                                                                          ,'Maintenance Capital', 'Maintenance Expense'
                                                                                          ,'COE Capital','COE Expense')
                                          AND [Project Reporting Year] = @Year
                                    THEN  [Schedule Actuals]

                              ELSE 0
                        END) AS [Schedule Actuals]
                  ,[Click End Date] AS [Schedule Out]

      ---- EXECUTE ---- [NO PRY FILTER!]
                  ,SUM(
                        CASE
                              WHEN [PDC Program] NOT IN ('ED Pole Repl', 'ED Pole Repl - Emergent'
                                                                  ,'Maintenance Capital','Maintenance Capital - Emergent'
                                                                  ,'Maintenance Expense','Maintenance Expense - Emergent'
                                                                  ,'COE Capital','COE Expense')
                                    AND [Program] <> 'ED WFM Dist Fault Anticipation'
                                    AND YEAR([Report Date]) = @Year
                                    THEN [Execute Actuals]
                              WHEN [PDC Program] IN ('ED Pole Repl', 'ED Pole Repl - Emergent'
                                                                  ,'Maintenance Capital','Maintenance Capital - Emergent'
                                                                  ,'Maintenance Expense','Maintenance Expense - Emergent'
                                                                  ,'COE Capital','COE Expense')
                                    AND YEAR([Reference Date]) = @Year
                                    AND [Notif Status] = 'COMP'
                                    THEN [Execute Actuals]
                              ELSE 0
                        END) AS [Execute Actuals]
                  ,[Execute Out]

      ---- IN WORKPLAN ----
                  ,SUM(
                        CASE
                              WHEN [Project Reporting Year] = @Year  THEN [In Workplan]
                              ELSE 0
                        END) AS [In Workplan]
            
      FROM  BSA.dbo.vw_WPML_PDC_IDDSEC

      WHERE [PDC Program] IS NOT NULL
                  AND (
                              ([Notif User Status] NOT LIKE '%CNCL%' AND [PDC Program] <> 'ED WFM Surge Arresters HFTD') OR
                              [PDC Program] = 'ED WFM Surge Arresters HFTD'  --Surge Arresters need CNCL
                        )
                  AND ( 
                              [Project Reporting Year] = @Year
                              OR YEAR([Report Date]) = @Year
                              OR (YEAR([Reference Date]) = @Year AND [Notif Status] = 'COMP'
                                    AND [PDC Program] IN ('ED Pole Repl', 'ED Pole Repl - Emergent'
                                                                  ,'Maintenance Capital','Maintenance Expense'
                                                                  ,'COE Capital','COE Expense')
                              )
                        )
                  AND [PDC Program] <> 'NOT IN PDC'
                  AND [PDC Program] IS NOT NULL

      GROUP BY
                        [PDC Program]
                        ,[Notification]
                        ,[Order]
                        ,[MAT]
                        ,[Region]
                        ,[Div]
                        ,[Authorized Funding Action (2024)]
                        ,[Project Reporting Year]
                        ,[Work Plan Date]
                        ,[Report Date]
                        ,[Reference Date]
                        ,[Notif Status]
                        ,[Notif User Status]
                        ,[Initiation Out]
                        ,[Design Out]
                        ,[Dependency Out]
                        ,[Schedule Out]
                        ,[CLICK End Date]
                        ,[Execute Out]
                  
),


---- BELOW ARE CTEs USING THE ABOVE CTEs ----

--This is taking our normalized IDDSEC actuals and sums just the ones that fit in our time

IDDSEC_Actuals AS(

            SELECT [PDC Program]
                  ,CASE
                              WHEN [PDC Program] IN ('Maintenance Capital', 'Maintenance Expense'
                                                            ,'COE Capital','COE Expense')
                                    THEN 'ED Maintenance'
                              ELSE 'ED Projects'
                        END as [Mega Process]
                  ,CASE
                        WHEN [PDC Program] IN ('Maintenance Capital', 'Maintenance Expense'
                                                            ,'COE Capital','COE Expense')
                              THEN 'Ron Richardson'
                        ELSE 'Sandra Cullings'
                        END as [MPO]
                  ,NULL as [Process]
                  ,SUM(CASE
                              WHEN [Initiation Out] <= @ActualsFilter THEN [Initiation Actuals]
                        END) AS [Initiation Actuals]
                  ,SUM(CASE
                              WHEN [Design Out] <= @ActualsFilter       THEN [Design Actuals]
                        END) AS [Design Actuals]
                  ,SUM(CASE
                              WHEN [Dependency Out] <= @ActualsFilter   THEN [Dependency Actuals]
                        END) AS [Dependency Actuals]
                  ,SUM([Schedule Actuals]) AS [Schedule Actuals]
                  ,SUM(CASE
                              WHEN [Execute Out] <= @ActualsFilter THEN [Execute Actuals]
                        END) AS [Execute Actuals without DOT]
                  ,SUM([In Workplan]) AS [Total in Workplan]
            FROM WPML_Actuals
            GROUP BY [PDC Program]
                              ,CASE
                                                WHEN [PDC Program] IN ('Maintenance Capital', 'Maintenance Expense'
                                                                              ,'COE Capital','COE Expense')
                                                      THEN 'ED Maintenance'
                                                ELSE 'ED Projects'
                                          END
                                    ,CASE
                                          WHEN [PDC Program] IN ('Maintenance Capital', 'Maintenance Expense'
                                                                              ,'COE Capital','COE Expense')
                                                THEN 'Ron Richardson'
                                          ELSE 'Sandra Cullings'
                                          END

),

--Gives the exact Throughput YTD targets at the particular week of the year


DOT_Rebaseline AS (
                  SELECT DISTINCT a.[PDC Program], [Rebaseline]
                  FROM  (SELECT DISTINCT [Program Nickname]
                              , CASE WHEN [Program Nickname] = 'ED COE Capital' THEN 'COE Capital'
                                     WHEN [Program Nickname] = 'ED COE Expense' THEN 'COE Expense'
                                     WHEN [Program Nickname] IN ( 'ED Maint EC Tags Expense','ED Maint Non-EC Tags Expense') THEN 'Maintenance Expense'
                                     WHEN [Program Nickname] IN ( 'ED Maint EC Tags Capital','ED Maint Non-EC Tags Capital') THEN 'Maintenance Capital'
                                     ELSE [Program Nickname]
                              END as [PDC Program]
                              , sum(ISNULL(a.[Rebaseline],0)) as [Rebaseline]
                              FROM ada.[Delivery].[DOT_Unit_Forecast_Comp] a
                              WHERE a.[Date Range] like '%2024%'  --@YEAR
                              --AND [Program Nickname] = 'ED WFM Surge Arresters HFTD'
                              GROUP BY [Program Nickname]
                              ) a
                              INNER JOIN bsa.dbo.vw_NewWOR_PDCTargets_2024 b ON a.[PDC Program] = b.[PDC Program]

                    --order by 1



),

--Gives the exact Throughput YTD targets at the particular week of the year
IDDE_DOT AS (

            SELECT  [PDC Program]
                        ,[FULL Week Number]
                        ,[Month2]
                        ,[Month]
                        ,SUM(ISNULL([Initiation YTD Target],0)) AS [Initiation Target]
                        ,SUM(ISNULL([Design YTD Target],0)) AS [Design Target]
                        ,SUM(ISNULL([Dependency YTD Target],0)) AS [Dependency Target]
                        ,SUM(ISNULL([Execute YTD Target],0)) AS [Execute Target]
                        ,SUM(CASE
                              WHEN [Program Nickname] = 'ED WFM Dist Fault Anticipation' THEN
                                    ISNULL([YTD Completions],0) --per request from Edward Peluso, DFA isn't tracked in SAP, must use DOT. 7.28.24 JZLX
                                    --This CASE statement simply brings in DOT completions for DOT, and zero for everything else
                              END) AS [YTD Completions]
            FROM bsa.dbo.vw_NewWOR_PDCTargets_2024
            WHERE [FULL Week Number] = @WeekFilter
                        AND [PDC Program] IS NOT NULL
            GROUP BY    [PDC Program]
                              ,[FULL Week Number]
                              ,[Month2]
                              ,[Month]
),

IDDSEC_Actuals_wDOTActuals AS (

      SELECT wpmlcte.*
            ,CASE
                  WHEN wpmlcte.[PDC Program] = 'ED WFM Line Sensors' THEN [Execute Actuals without DOT] + dotcte.[YTD Completions]
                  ELSE wpmlcte.[Execute Actuals without DOT]
            END AS [Execute Actuals]
      FROM IDDSEC_Actuals wpmlcte
            LEFT JOIN IDDE_DOT dotcte
                  ON wpmlcte.[PDC Program] = dotcte.[PDC Program]
),


ScheduleTargets AS (

            SELECT [PDC Program],[Month2],[Month],SUM([Execute YTD Forecast]) AS [Schedule Target]
            FROM bsa.dbo.vw_NewWOR_PDCTargets_2024
            WHERE [FULL Week Number] = (@WeekFilter+4)
                        AND [PDC Program] IS NOT NULL
            GROUP BY [PDC Program],[Month2],[Month]
)

-- STACKABLE FORMAT
SELECT
    @Output AS [Output],
    act.[Mega Process],
    act.[MPO],
    act.[Process],
    dot.[PDC Program],
    '' AS [Unit of Measure],
    'Annual Target' AS [Phase],
    ROUND([Initiation Target],0) AS [Plan],
    '' AS [Completions],
    '' AS [% to Plan],
    '' AS [On Track],
    '' AS [RAG]
FROM IDDE_DOT dot
LEFT JOIN IDDSEC_Actuals act ON dot.[PDC Program] = act.[PDC Program]

UNION ALL

SELECT
    @Output AS [Output],
    act.[Mega Process],
    act.[MPO],
    act.[Process],
    dot.[PDC Program],
    '' AS [Unit of Measure],
    'Initiation' AS [Phase],
    ROUND(dot.[Initiation Target],0) AS [Plan],
    ISNULL(act.[Initiation Actuals],0) AS [Completions],
    CASE  
        WHEN ISNULL(dot.[Initiation Target],0) = 0 THEN 0
        ELSE ROUND((ISNULL(act.[Initiation Actuals],0)/dot.[Initiation Target]),4)
    END AS [% to Plan],
    '' AS [On Track],
    '' AS [RAG]
FROM IDDE_DOT dot
LEFT JOIN IDDSEC_Actuals act ON dot.[PDC Program] = Act.[PDC Program]

UNION ALL

SELECT
    @Output AS [Output],
    act.[Mega Process],
    act.[MPO],
    act.[Process],
    dot.[PDC Program],
    '' AS [Unit of Measure],
    'Design' AS [Phase],
    ROUND(dot.[Design Target],0) AS [Plan],
    ISNULL(act.[Design Actuals],0) AS [Completions],
    CASE  
        WHEN ISNULL(dot.[Design Target],0) = 0 THEN 0
        ELSE ROUND((ISNULL(act.[Design Actuals],0)/dot.[Design Target]),4)
    END AS [% to Plan],
    '' AS [On Track],
    '' AS [RAG]
FROM IDDE_DOT dot
LEFT JOIN IDDSEC_Actuals act ON dot.[PDC Program] = Act.[PDC Program]

UNION ALL

SELECT
    @Output AS [Output],
    act.[Mega Process],
    act.[MPO],
    act.[Process],
    dot.[PDC Program],
    '' AS [Unit of Measure],
    'Dependencies' AS [Phase],
    ROUND(dot.[Dependency Target],0) AS [Plan],
    ISNULL(act.[Dependency Actuals],0) AS [Completions],
    CASE  
        WHEN ISNULL(dot.[Dependency Target],0) = 0 THEN 0
        ELSE ROUND((ISNULL(act.[Dependency Actuals],0)/dot.[Dependency Target]),4)
    END AS [% to Plan],
    '' AS [On Track],
    '' AS [RAG]
FROM IDDE_DOT dot
LEFT JOIN IDDSEC_Actuals act ON dot.[PDC Program] = Act.[PDC Program]

UNION ALL

SELECT
    @Output AS [Output],
    act.[Mega Process],
    act.[MPO],
    act.[Process],
    dot.[PDC Program],
    '' AS [Unit of Measure],
    'Schedule' AS [Phase],
    ROUND(dot.[Schedule Target],0) AS [Plan],
    ISNULL(act.[Schedule Actuals],0) AS [Completions],
    CASE  
        WHEN ISNULL(dot.[Schedule Target],0) = 0 THEN 0
        ELSE ROUND((ISNULL(act.[Schedule Actuals],0)/dot.[Schedule Target]),4)
    END AS [% to Plan],
    '' AS [On Track],
    '' AS [RAG]
FROM ScheduleTargets dot
LEFT JOIN IDDSEC_Actuals act ON dot.[PDC Program] = Act.[PDC Program]

UNION ALL

SELECT
    @Output AS [Output],
    act.[Mega Process],
    act.[MPO],
    act.[Process],
    dot.[PDC Program],
    '' AS [Unit of Measure],
    'Execute' AS [Phase],
    ROUND(dot.[Execute Target],0) AS [Plan],
    ISNULL(act.[Execute Actuals],0) AS [Completions],
    CASE  
        WHEN ISNULL(dot.[Execute Target],0) = 0 THEN 0
        ELSE ROUND((ISNULL(act.[Execute Actuals],0)/dot.[Execute Target]),4)
    END AS [% to Plan],
    '' AS [On Track],
    '' AS [RAG]
FROM IDDE_DOT dot
LEFT JOIN IDDSEC_Actuals_wDOTActuals act ON dot.[PDC Program] = Act.[PDC Program]

UNION ALL

SELECT
    @Output AS [Output],
    act.[Mega Process],
    act.[MPO],
    act.[Process],
    dot.[PDC Program],
    '' AS [Unit of Measure],
    'Total in WP' AS [Phase],
    '' AS [Plan],
    act.[Total in Workplan] AS [Completions],
    '' AS [% to Plan],
    '' AS [On Track],
    'GRAY' [RAG]
FROM IDDE_DOT dot
LEFT JOIN IDDSEC_Actuals act ON dot.[PDC Program] = Act.[PDC Program]

UNION ALL

SELECT
    @Output AS [Output],
    act.[Mega Process],
    act.[MPO],
    act.[Process],
    dot.[PDC Program],
    '' AS [Unit of Measure],
    'EOY Forecast' AS [Phase],
    '' AS [Plan],
    act.[Total in Workplan] AS [Completions],
    '' AS [% to Plan],
    '' AS [On Track],
    'GRAY' [RAG]
FROM IDDE_DOT dot
LEFT JOIN IDDSEC_Actuals act ON dot.[PDC Program] = Act.[PDC Program]

UNION ALL

SELECT
    @Output AS [Output],
    act.[Mega Process],
    act.[MPO],
    act.[Process],
    dot.[PDC Program],
    '' AS [Unit of Measure],
    'Rebaseline' AS [Phase],
    0 AS [Plan],
    dot.[Rebaseline] AS [Completions],
    '' AS [% to Plan],
    '' AS [On Track],
    'GRAY' [RAG]
FROM DOT_Rebaseline dot
LEFT JOIN IDDSEC_Actuals act ON dot.[PDC Program] = Act.[PDC Program]

ORDER BY [PDC Program];
