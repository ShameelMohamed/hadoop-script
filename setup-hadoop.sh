#!/bin/bash

echo "🚀 Starting Hadoop Setup..."

# STEP 1: Install Java 8
sudo apt update -y
sudo apt install -y openjdk-8-jdk ssh

# Force Java 8 as default
sudo update-alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java
sudo update-alternatives --set javac /usr/lib/jvm/java-8-openjdk-amd64/bin/javac

# Verify Java
java -version

# STEP 2: Create Hadoop user (if not exists)
id -u hadoop &>/dev/null || sudo adduser --disabled-password --gecos "" hadoop
echo "hadoop:hadoop" | sudo chpasswd

# STEP 3: Run setup as Hadoop user
sudo -u hadoop bash << 'EOF'

echo "👤 Switched to Hadoop user"

# Setup SSH
mkdir -p ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa <<< y
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

ssh -o StrictHostKeyChecking=no localhost "echo SSH OK"

# Download Hadoop
cd ~
wget -q https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz

tar -xzf hadoop-3.3.6.tar.gz
mv hadoop-3.3.6 hadoop

# Environment variables
cat <<EOT >> ~/.bashrc
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/home/hadoop/hadoop
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
EOT

source ~/.bashrc

# Configure JAVA_HOME in Hadoop
sed -i 's|export JAVA_HOME=.*|export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64|' $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# Hadoop directories
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
<name>mapreduce.framework.name</name>
<value>yarn</value>
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

# Format Namenode (only if not already formatted)
if [ ! -d "/home/hadoop/hadoopdata/hdfs/namenode/current" ]; then
    hdfs namenode -format
fi

# Start Hadoop
start-dfs.sh
start-yarn.sh

sleep 5

echo "📊 Checking running services..."
jps

# Auto-fix if SecondaryNameNode missing
if ! jps | grep -q SecondaryNameNode; then
    echo "⚠️ Starting SecondaryNameNode manually..."
    hadoop-daemon.sh start secondarynamenode
fi

sleep 3

echo "✅ FINAL JPS OUTPUT:"
jps

echo "🌐 Namenode UI: http://localhost:9870"
echo "🌐 ResourceManager UI: http://localhost:8088"

EOF

echo "🎉 HADOOP SETUP COMPLETED SUCCESSFULLY!"
