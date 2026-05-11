SELECT
 sent_month,
 id_account,
 COUNT(DISTINCT id_message)
   / SUM(COUNT(DISTINCT id_message)) OVER (PARTITION BY sent_month)
   * 100 AS sent_msg_percent,
 MIN(sent_date) AS first_sent_date,
 MAX(sent_date) AS last_sent_date
FROM
 (
   SELECT
     DATE_TRUNC(sent_date, MONTH) AS sent_month,
     id_account,
     id_message,
     sent_date
   FROM
     (
       SELECT
         es.id_account AS id_account,
         id_message,
         DATE(DATETIME_ADD(ses.date, INTERVAL es.sent_date DAY)) AS sent_date
       FROM data-analytics-mate.DA.session ses
       JOIN data-analytics-mate.DA.account_session acs
         USING (ga_session_id)
       JOIN data-analytics-mate.DA.email_sent es
         ON es.id_account = acs.account_id
     )
 )
GROUP BY sent_month, id_account;