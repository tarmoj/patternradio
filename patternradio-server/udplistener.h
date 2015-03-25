#ifndef UDPLISTENER_H
#define UDPLISTENER_H

#include <QThread>
#include <QUdpSocket>
#include <QDateTime>


class UdpListener : public QThread
{
	Q_OBJECT
public:
	explicit UdpListener(int port);

signals:
	void newHeartRate(QString heartMessage);

public slots:
	void readyRead();
	void run();

private:
	QUdpSocket *socket;
	bool mStop;
	uint lastTime;

};

#endif // UDPLISTENER_H
