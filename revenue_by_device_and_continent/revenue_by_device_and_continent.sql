WITH
 revenue_from_devices AS (
   SELECT
     sp.continent AS Continent,
     ROUND(SUM(prod.price), 2) AS Revenue,
     ROUND(SUM(CASE WHEN sp.device = 'mobile' THEN prod.price END), 2) AS Revenue_from_Mobile,
     ROUND(SUM(CASE WHEN sp.device = 'desktop' THEN prod.price END), 2) AS Revenue_from_Desktop
   FROM `data-analytics-mate.DA.session_params` sp
   LEFT JOIN `data-analytics-mate.DA.order` ord
     USING (ga_session_id)
   JOIN `data-analytics-mate.DA.product` prod
     ON ord.item_id = prod.item_id
   GROUP BY Continent
 ),
 perc_revenue_from_total AS (
   SELECT
     Continent,
     Revenue,
     Revenue_from_Mobile,
     Revenue_from_Desktop,
     ROUND(Revenue / SUM(Revenue) OVER () * 100, 2) AS Perc_Revenue_From_Total
   FROM revenue_from_devices
 ),
 account_info AS (
   SELECT
     sp.continent,
     COUNT(DISTINCT acc.id) AS Account_Count,
     COUNT(DISTINCT CASE WHEN is_verified = 1 THEN acc.id END) AS Verified_Account,
     COUNT(DISTINCT sp.ga_session_id) AS Session_Count
   FROM data-analytics-mate.DA.session_params sp
   LEFT JOIN data-analytics-mate.DA.account_session acs
     ON acs.ga_session_id = sp.ga_session_id
   LEFT JOIN data-analytics-mate.DA.account acc
     ON acc.id = acs.account_id
   GROUP BY sp.continent
 )
SELECT
 aci.Continent,
 prft.Revenue,
 prft.Revenue_from_Mobile,
 prft.Revenue_from_Desktop,
 prft.Perc_Revenue_From_Total,
 aci.Account_Count,
 aci.Verified_Account,
 aci.Session_Count
FROM account_info aci
LEFT JOIN perc_revenue_from_total prft
 ON aci.continent = prft.continent;