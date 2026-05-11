#Використовуємо набір CTE для того, щоб спростити основний запит.
WITH
 account_info AS (
  /* Extract basic fields for accounts and emails to avoid redundant JOINs. Include account_id specifically to link CTEs, even though it’s excluded from the final output.
    Use DISTINCT to prevent duplicate rows if account parameters (like country) have changed.
  */
   SELECT DISTINCT
     DATE(ses.date) AS date,
     sp.country AS country,
     acc.send_interval AS send_interval,
     acc.is_verified AS is_verified,
     acc.is_unsubscribed AS is_unsubscribed,
     acc.id AS ID
   FROM `DA.account` acc
   JOIN `DA.account_session` acs
     ON acc.id = acs.account_id
   JOIN `DA.session` ses
     ON acs.ga_session_id = ses.ga_session_id
   JOIN `DA.session_params` sp
     ON acs.ga_session_id = sp.ga_session_id
 ),
 account_not_combined AS (
  /*
  Prepare account data to be merged with email dispatch records.
  Calculate the count of unique accounts.
  Create placeholder (zero-value) columns for email metrics to simplify the UNION ALL query later.
  */
   SELECT
     date,
     country,
     send_interval,
     is_verified,
     is_unsubscribed,
     COUNT(DISTINCT ID) AS account_cnt,
     0 AS sent_msg,
     0 AS open_msg,
     0 AS visit_msg
   FROM account_info
   GROUP BY date, country, send_interval, is_verified, is_unsubscribed
 ),
 msg_cnt AS (
  /*
  Calculate core metrics: total emails sent, opens, and clicks.
  Use LEFT JOIN to retain sent emails that have no opens or clicks.
  */
   SELECT
     es.id_account AS acc_id,
     es.sent_date AS sent_date,
     COUNT(DISTINCT es.id_message) AS sent_msg,
     COUNT(DISTINCT eo.id_message) AS open_msg,
     COUNT(DISTINCT ev.id_message) AS visit_msg
   FROM `DA.email_sent` es
   LEFT JOIN DA.email_open eo
     ON eo.id_message = es.id_message
   LEFT JOIN DA.email_visit ev
     ON es.id_message = ev.id_message
   GROUP BY es.id_account, es.sent_date
 ),
 msg_not_combined AS (
  /*
  Prepare email data to be merged with account data.
  Calculate the initial send date, as the sent_date field in the DB represents "days since account creation" rather than a calendar date.
  Create placeholder columns for the account count to simplify the UNION ALL query later.
  */
   SELECT
     DATE_ADD(date, INTERVAL msg_cnt.sent_date DAY) AS date,
     country,
     send_interval,
     is_verified,
     is_unsubscribed,
     0 AS account_cnt,
     msg_cnt.sent_msg AS sent_msg,
     msg_cnt.open_msg AS open_msg,
     msg_cnt.visit_msg AS visit_msg
   FROM account_info
   JOIN msg_cnt
     ON account_info.ID = msg_cnt.acc_id
 ),
 combined_acc_msg AS (
  /*
  Combine the core parameter datasets.
  Use UNION ALL for better performance; we will aggregate the data later to properly combine the records.
  */
   SELECT *
   FROM account_not_combined
   UNION ALL
   SELECT *
   FROM msg_not_combined
 ),
 aggregated_acc_msg AS (
  /*
  Aggregate the combined table to "hide" the rows and remove zero values across columns.
  This ensures all data is merged into a single row per record.
  */
   SELECT
     date,
     country,
     send_interval,
     is_verified,
     is_unsubscribed,
     SUM(account_cnt) AS account_cnt,
     SUM(sent_msg) AS sent_msg,
     SUM(open_msg) AS open_msg,
     SUM(visit_msg) AS visit_msg,
   FROM combined_acc_msg
   GROUP BY date, country, send_interval, is_verified, is_unsubscribed
 ),
 totals AS (
  /*
  Calculate totals by country.
  Since we need global totals per country, we use PARTITION BY country within the window function. We omit ORDER BY because we need the full partition total rather than a running accumulation.
  */
   SELECT
     *,
     SUM(account_cnt) OVER (PARTITION BY country) AS total_country_account_cnt,
     SUM(sent_msg) OVER (PARTITION BY country) AS total_country_sent_cnt
   FROM aggregated_acc_msg
 )

  /*
  Add a final SELECT to rank countries based on global totals.
  PARTITION BY is omitted here because we are comparing countries against each other, not within themselves.
  Rank by the total number of accounts in each country using ORDER BY.
  */
SELECT *,
 DENSE_RANK() OVER (ORDER BY total_country_account_cnt DESC) AS rank_total_country_account_cnt,
 DENSE_RANK() OVER (ORDER BY total_country_sent_cnt DESC) AS rank_total_country_sent_cnt
FROM totals
# Filter to retain only records where rank_total_country_account_cnt or rank_total_country_sent_cnt is 10 or less.
QUALIFY rank_total_country_account_cnt <= 10 OR rank_total_country_sent_cnt <= 10;