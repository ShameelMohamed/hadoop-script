#!/bin/bash

echo "🚀 Starting FULL Hadoop Setup..."

# Ask for sudo upfront
sudo -v || exit 1

# STEP 1: Install dependencies
sudo apt update -y
sudo apt install -y openjdk-8-jdk ssh wget

# STEP 2: Force Java 8
sudo update-alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java
sudo update-alternatives --set javac /usr/lib/jvm/java-8-openjdk-amd64/bin/javac

echo "✅ Java version:"
java -version

# STEP 3: Create Hadoop user if not exists
if id "hadoop" &>/dev/null; then
    echo "👤 Hadoop user already exists"
else
    sudo adduser --disabled-password --gecos "" hadoop
    echo "hadoop:hadoop" | sudo chpasswd
fi

# STEP 4: Execute as Hadoop user
sudo -u hadoop bash << 'EOF'

echo "👤 Running as Hadoop user"

cd ~

# STEP 5: Setup SSH
mkdir -p ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa <<< y
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

ssh -o StrictHostKeyChecking=no localhost "echo SSH OK"

# STEP 6: Download Hadoop (if not exists)
if [ ! -d "$HOME/hadoop" ]; then
    wget -q https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
    tar -xzf hadoop-3.3.6.tar.gz
    mv hadoop-3.3.6 hadoop
fi

# STEP 7: Set environment variables
cat <<EOT >> ~/.bashrc
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/home/hadoop/hadoop
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
EOT

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/home/hadoop/hadoop
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

# STEP 8: Fix JAVA_HOME inside Hadoop
sed -i 's|export JAVA_HOME=.*|export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64|' $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# STEP 9: Create directories
mkdir -p ~/hadoopdata/hdfs/namenode
mkdir -p ~/hadoopdata/hdfs/datanode

# STEP 10: Config files

cat <<EOT > $HADOOP_HOME/etc/hadoop/core-site.xml
<configuration>
<property>
<name>fs.defaultFS</name>
<value>hdfs://localhost:9000</value>
</property>
</configuration>
EOT

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

cp $HADOOP_HOME/etc/hadoop/mapred-site.xml.template $HADOOP_HOME/etc/hadoop/mapred-site.xml

cat <<EOT > $HADOOP_HOME/etc/hadoop/mapred-site.xml
<configuration>
<property>
<name>mapreduce.framework.name</name>
<value>yarn</value>
</property>
</configuration>
EOT

cat <<EOT > $HADOOP_HOME/etc/hadoop/yarn-site.xml
<configuration>
<property>
<name>yarn.nodemanager.aux-services</name>
<value>mapreduce_shuffle</value>
</property>
</configuration>
EOT

# STEP 11: Format namenode (only first time)
if [ ! -d "/home/hadoop/hadoopdata/hdfs/namenode/current" ]; then
    hdfs namenode -format
fi

# STEP 12: Start Hadoop
$HADOOP_HOME/sbin/start-dfs.sh
$HADOOP_HOME/sbin/start-yarn.sh

sleep 5

# STEP 13: Ensure all 5 daemons
if ! jps | grep -q SecondaryNameNode; then
    $HADOOP_HOME/sbin/hadoop-daemon.sh start secondarynamenode
fi

sleep 3

echo "🎯 FINAL JPS OUTPUT:"
jps

echo "🌐 Namenode UI: http://localhost:9870"
echo "🌐 ResourceManager UI: http://localhost:8088"

EOF

echo "🎉 HADOOP SETUP COMPLETED SUCCESSFULLY!"
