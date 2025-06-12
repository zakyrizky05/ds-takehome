-- hitung score rfm
WITH rfm AS (
  SELECT
    customer_id,
    MAX(order_date) AS last_order_date,
    (CURRENT_DATE - MAX(order_date)) AS recency,
    COUNT(order_id) AS frequency,
    SUM(payment_value) AS monetary
  FROM ds_test
  GROUP BY customer_id
),

-- score R, F, dan M dengan NTILE
scored_rfm AS(
    SELECT
        customer_id,
        last_order_date,
        recency,
        frequency,
        monetary,

        NTILE(5) OVER (ORDER BY recency ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC) AS m_score

    FROM rfm
),

-- segmentasi RFM
segmented AS(
    SELECT *,
        CASE
            WHEN r_score = 5 AND f_score = 5 AND m_score = 5 THEN 'Champions'
            WHEN r_score >= 4 AND f_score >= 4 THEN 'Loyal Customers'
            WHEN r_score = 5 AND f_score <= 2 THEN 'New Customers'
            WHEN r_score >= 4 AND f_score BETWEEN 3 AND 4 THEN 'Potential Loyalists'
            WHEN r_score BETWEEN 3 AND 4 AND f_score BETWEEN 2 AND 3 THEN 'Promising'
            WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost'
            ELSE 'Others'
        END AS segment
    FROM scored_rfm
)

-- output
SELECT * FROM segmented
ORDER BY segment, customer_id;

-- repeat purchase bulanan
WITH monthly_purchases AS (
  SELECT
    customer_id,
    DATE_TRUNC('month', order_date) AS purchase_month,
    COUNT(order_id) AS order_count
  FROM ds_test
  GROUP BY customer_id, purchase_month
),
repeat_purchases AS (
  SELECT
    purchase_month,
    COUNT(DISTINCT customer_id) AS repeat_customer_count
  FROM monthly_purchases
  WHERE order_count > 1
  GROUP BY purchase_month
)

SELECT * FROM repeat_purchases
ORDER BY purchase_month;


/*
RFM Segmentation & Repeat Purchase Analysis

1. RFM Segmentation:
   - Menghitung nilai Recency, Frequency, dan Monetary untuk setiap customer dari data `ds_test`.
   - Memberikan skor 1–5 untuk masing-masing aspek menggunakan NTILE (kuantil 5).
   - Menentukan segmentasi pelanggan berdasarkan kombinasi skor:
     - Champions, Loyal Customers, New Customers, Potential Loyalists, Promising, At Risk, Lost, Others.
   - Hasil akhir: Daftar pelanggan beserta segmentasi mereka.

2. Repeat Purchase Analysis (Monthly):
   - Menghitung total pesanan tiap pelanggan per bulan.
   - Mengidentifikasi pelanggan yang melakukan lebih dari satu pembelian dalam satu bulan (repeat purchase).
   - Menghasilkan jumlah pelanggan repeat purchase untuk setiap bulan (`repeat_customer_count`).

Tujuan: Memahami perilaku pelanggan secara menyeluruh — baik dari nilai strategis jangka panjang (RFM) maupun keterlibatan bulanan mereka (repeat purchase).
*/