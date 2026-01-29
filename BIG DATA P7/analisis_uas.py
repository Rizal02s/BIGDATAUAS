import os
import sys

# 1. KONFIGURASI PATH (WAJIB BENAR)
spark_home = r'C:\spark' # Sesuaikan jika folder spark Anda berbeda nama
os.environ['SPARK_HOME'] = spark_home
os.environ['JAVA_HOME'] = r'C:\Program Files\Eclipse Adoptium\jdk-8.0.472.8-hotspot'
os.environ['PYSPARK_PYTHON'] = sys.executable
os.environ['PYSPARK_DRIVER_PYTHON'] = sys.executable

# 2. MENAMBAHKAN LIBRARY SPARK KE PYTHON PATH SECARA MANUAL
# Ini untuk mengatasi error 'JavaPackage' object is not callable
sys.path.append(os.path.join(spark_home, 'python'))
# Mencari file zip py4j di folder spark/python/lib
py4j_path = [os.path.join(spark_home, 'python', 'lib', f) for f in os.listdir(os.path.join(spark_home, 'python', 'lib')) if f.endswith('.zip')]
for path in py4j_path:
    sys.path.append(path)

from pyspark.sql import SparkSession
from pyspark.sql.functions import col
import matplotlib.pyplot as plt

# 3. INISIALISASI SPARK SESSION
spark = SparkSession.builder \
    .appName("Analisis Instagram UAS") \
    .config("spark.driver.memory", "2g") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")

try:
    print("--- PySpark Berhasil Terhubung! ---")
    # Membaca data dari HDFS
    path_hdfs = "hdfs://localhost:9000/data_uas/instagram_users.csv"
    df = spark.read.option("header", "true").option("inferSchema", "true").csv(path_hdfs)

    # Cleaning data sesuai syarat UAS
    df_clean = df.withColumn("followers_count", col("followers_count").cast("int")).dropna(subset=["followers_count"])

    # Mengambil Top 10
    top_10_pdf = df_clean.orderBy(col("followers_count").desc()).limit(10).toPandas()

    if not top_10_pdf.empty:
        plt.figure(figsize=(10, 5))
        plt.bar(top_10_pdf['user_id'].astype(str), top_10_pdf['followers_count'], color='purple')
        plt.title('Top 10 Influencer - Tugas UAS Big Data')
        plt.show()

finally:
    spark.stop()