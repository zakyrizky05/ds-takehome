Saya mendeteksi setidaknya 2 anomali pada fitur decoy_noise dengan menggunakan rata-rata dan standar deviasi. Nilai yang jauh di luar batas normal (lebih dari 3 standar deviasi dari rata-rata) dianggap anomali.

Temuan ini menunjukkan adanya data yang menyimpang cukup jauh dari pola umum, yang bisa jadi indikasi noise atau aktivitas tidak biasa.

Secara keseluruhan, terdeteksi anomali sebanyak 129

SELECT *
FROM (
    SELECT *,
           AVG(decoy_noise) OVER () AS mean_noise,
           STDDEV_POP(decoy_noise) OVER () AS std_noise,
           (decoy_noise - AVG(decoy_noise) OVER ()) / NULLIF(STDDEV_POP(decoy_noise) OVER (), 0) AS z_score
    FROM ds_test
) sub
WHERE ABS(z_score) > 3;