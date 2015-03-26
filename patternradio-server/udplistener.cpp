#include "udplistener.h"
#include <QFile>
#include <QDateTime>

#define OFFTIME 60 // if no signal form HR monitor, think it is off
#define LOGFILE "heartrate.log"

UdpListener::UdpListener(int port)

{
	socket = new QUdpSocket(this); // The most common way to use QUdpSocket class is // to bind to an address and port using bind() // bool QAbstractSocket::bind(const QHostAddress & address, // quint16 port = 0, BindMode mode = DefaultForPlatform)
	socket->bind(QHostAddress::Any, port);
	lastTime = QDateTime::currentDateTime().toTime_t();
	connect(socket, SIGNAL(readyRead()), this, SLOT(readyRead()));
}

void UdpListener::readyRead()
{
	 QByteArray buffer; buffer.resize(socket->pendingDatagramSize());
	 QHostAddress sender;
	 quint16 senderPort;

	 socket->readDatagram(buffer.data(), buffer.size(), &sender, &senderPort);

	 qDebug() << "Message: " << buffer;
	 QString message = QString(buffer);
	 if (message.startsWith("heart")) { // heart-rate comes in as "heart,72"
		 lastTime = QDateTime::currentDateTime().toTime_t(); // to register if it is sent regularly
		 QString heartRate = message.split(",")[1];
		 qDebug()<<"New heart-rate: " << heartRate;
		 emit newHeartRate("heart,"+heartRate);
		 QFile logFile(LOGFILE); // log heartrate into logfile
		 if (logFile.open(QIODevice::Append)) {
			 logFile.write((QDateTime::currentDateTime().toString("dd.MM.yy hh:mm:ss")+","+heartRate).toLocal8Bit()+"\n");
			 logFile.close();
		 } else
			 qDebug()<<"Could not open logfile "<<LOGFILE;
	 }
}

void UdpListener::run()
{
	while(true) {
		uint now= QDateTime::currentDateTime().toTime_t();
		if (now-lastTime>OFFTIME) {
			qDebug()<<"No signal from HR monitor for "<<OFFTIME<<" seconds.";
			emit newHeartRate("heart,-1");
			lastTime = now;
		}
		sleep(1);
	}
}



