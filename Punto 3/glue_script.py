import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Leer datos del bucket de S3
s3_input_path = "s3://your-bucket-name/input/" # Reemplazar con la ruta de su bucket y carpeta
df = spark.read.format("csv").option("header", "true").load(s3_input_path)

# Procesar datos (opcional)
# ...

# Escribir datos en la tabla de DynamoDB
df.write.format("dynamodb").option("tableName", "your-dynamodb-table-name").save() # Reemplazar con el nombre de su tabla DynamoDB

job.commit()