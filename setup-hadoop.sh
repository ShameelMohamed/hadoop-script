#!/bin/bash

echo "🚀 Starting Hadoop Setup..."

# STEP 1: Install Java
sudo apt update -y
sudo apt install -y openjdk-8-jdk

# STEP 2: Verify Java
java -version

# STEP 3: Install SSH
sudo apt install -y ssh

# STEP 4: Create Hadoop user
sudo adduser --disabled-password --gecos "" hadoop
echo "hadoop:hadoop" | sudo chpasswd

# STEP 5: Switch to Hadoop user
sudo -u hadoop bash << 'EOF'

# STEP 6: Generate SSH Key
ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa

# STEP 7: Set permissions
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 640 ~/.ssh/authorized_keys

# STEP 8: Test SSH localhost
ssh -o StrictHostKeyChecking=no localhost "echo SSH Working"

# STEP 9: Switch user again
cd ~

# STEP 10: Install Hadoop
wget https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz

tar -xvzf hadoop-3.3.6.tar.gz
mv hadoop-3.3.6 hadoop

# Set environment variables
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

# Configure JAVA_HOME
sed -i 's|export JAVA_HOME=.*|export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64|' $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# STEP 11: Configure Hadoop

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

# STEP 12: Start Hadoop
hdfs namenode -format
start-all.sh

# Check services
jps

# STEP 13: Install net-tools
sudo apt install -y net-tools || true

ifconfig || ip a

echo "🌐 Namenode UI: http://localhost:9870"
echo "🌐 Resource Manager: http://localhost:8088"

# STEP 14: Verify Hadoop
hdfs dfs -mkdir /test1
hdfs dfs -mkdir /logs

hdfs dfs -ls /

hdfs dfs -put /var/log/* /logs/ || true

echo "✅ HDFS Test Completed"

# STEP 15: Stop Hadoop (optional)
# stop-all.sh

EOF

echo "🎉 FULL HADOOP SETUP DONE!"
