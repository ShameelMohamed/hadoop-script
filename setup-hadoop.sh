#!/bin/bash

# -------------------------------
# STEP 1: Update & Install Java
# -------------------------------
sudo apt update -y
sudo apt install -y openjdk-8-jdk

# STEP 2: Verify Java
java -version

# -------------------------------
# STEP 3: Install SSH
# -------------------------------
sudo apt install -y ssh

# -------------------------------
# STEP 4: Create Hadoop User
# -------------------------------
sudo adduser --disabled-password --gecos "" hadoop
echo "hadoop:hadoop" | sudo chpasswd

# -------------------------------
# STEP 5: Switch to Hadoop User
# -------------------------------
sudo -u hadoop bash << 'EOF'

# -------------------------------
# STEP 6: Configure SSH
# -------------------------------
ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa

cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 640 ~/.ssh/authorized_keys

# STEP 7 & 8: SSH localhost test
ssh -o StrictHostKeyChecking=no localhost "echo SSH OK"

# STEP 9: Ensure Hadoop user
cd ~

# -------------------------------
# STEP 10: Download & Install Hadoop
# -------------------------------
wget https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz

tar -xvzf hadoop-3.3.6.tar.gz
mv hadoop-3.3.6 hadoop

# -------------------------------
# Set Environment Variables
# -------------------------------
cat <<EOT >> ~/.bashrc

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/home/hadoop/hadoop
export HADOOP_INSTALL=\$HADOOP_HOME
export HADOOP_MAPRED_HOME=\$HADOOP_HOME
export HADOOP_COMMON_HOME=\$HADOOP_HOME
export HADOOP_HDFS_HOME=\$HADOOP_HOME
export HADOOP_YARN_HOME=\$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_HOME/lib/native
export PATH=\$PATH:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin
export HADOOP_OPTS="-Djava.library.path=\$HADOOP_HOME/lib/native"

EOT

source ~/.bashrc

# -------------------------------
# Configure hadoop-env.sh
# -------------------------------
sed -i 's|export JAVA_HOME=.*|export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64|' $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# -------------------------------
# STEP 11: Configure Hadoop
# -------------------------------

mkdir -p ~/hadoopdata/hdfs/namenode
mkdir -p ~/hadoopdata/hdfs/datanode

# core-site.xml
cat <<EOT > $HADOOP_HOME/etc/hadoop/core-site.xml
<configuration>
<property>
<name>fs.defaultFS</name>
<value>hdfs://localhost:9000</value>
</property>
</configuration>
EOT

# hdfs-site.xml
cat <<EOT > $HADOOP_HOME/etc/hadoop/hdfs-site.xml
<configuration>
<property>
<name>dfs.replication</name>
<value>1</value>
</property>
<property>
<name>dfs.namenode.name.dir</name>
<value>file:///home/hadoop/hadoopdata/hdfs/namenode</value>
</property>
<property>
<name>dfs.datanode.data.dir</name>
<value>file:///home/hadoop/hadoopdata/hdfs/datanode</value>
</property>
</configuration>
EOT

# mapred-site.xml
cp $HADOOP_HOME/etc/hadoop/mapred-site.xml.template $HADOOP_HOME/etc/hadoop/mapred-site.xml

cat <<EOT > $HADOOP_HOME/etc/hadoop/mapred-site.xml
<configuration>
<property>
<name>yarn.app.mapreduce.am.env</name>
<value>HADOOP_MAPRED_HOME=\$HADOOP_HOME</value>
</property>
<property>
<name>mapreduce.map.env</name>
<value>HADOOP_MAPRED_HOME=\$HADOOP_HOME</value>
</property>
<property>
<name>mapreduce.reduce.env</name>
<value>HADOOP_MAPRED_HOME=\$HADOOP_HOME</value>
</property>
</configuration>
EOT

# yarn-site.xml
cat <<EOT > $HADOOP_HOME/etc/hadoop/yarn-site.xml
<configuration>
<property>
<name>yarn.nodemanager.aux-services</name>
<value>mapreduce_shuffle</value>
</property>
</configuration>
EOT

# -------------------------------
# STEP 12: Start Hadoop
# -------------------------------
hdfs namenode -format

start-all.sh

jps

# -------------------------------
# STEP 13: Install net-tools
# -------------------------------
sudo apt install -y net-tools || true
ifconfig || ip a

# -------------------------------
# STEP 14: Verify Hadoop
# -------------------------------
hdfs dfs -mkdir /test1
hdfs dfs -mkdir /logs

hdfs dfs -ls /

hdfs dfs -put /var/log/* /logs/ || true

echo "Check Namenode UI: http://localhost:9870"
echo "Check Resource Manager: http://localhost:8088"

# -------------------------------
# STEP 15: Stop Hadoop (optional)
# -------------------------------
# stop-all.sh

EOF

echo "✅ FULL HADOOP SETUP COMPLETED"
