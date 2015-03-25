#include <QCoreApplication>
#include "wsserver.h"
#include "csengine.h"
#include "udplistener.h"

int main(int argc, char *argv[])
{
	QCoreApplication a(argc, argv);

	WsServer *wsServer;
	wsServer = new WsServer(10010);

	UdpListener udpListener(10011);
	udpListener.start();

	CsEngine cs("null");//"../patterngame-changetempo.csd"); // TODO: CurrentDir ..//patterngame-changetempo.csd

	QObject::connect(wsServer,SIGNAL(newMessage(QString)),&cs,SLOT(handleMessage(QString)) );
	QObject::connect(&cs, SIGNAL(sendNewPattern(int)), wsServer, SLOT(setFreeToPlay(int)));
	QObject::connect(wsServer, SIGNAL(newPropertyValue(QString,double)), &cs, SLOT(handleChannelChange(QString,double)));
	QObject::connect(wsServer, SIGNAL(newCodeToComplie(QString)) , &cs, SLOT(compileOrc(QString)));
    QObject::connect(&cs, SIGNAL(doSomething(int)),wsServer, SLOT(cutTheSilence(int)));
	QObject::connect(&udpListener,SIGNAL(newHeartRate(QString)), wsServer, SLOT(sendToMonitors(QString)));



    cs.start();


	return a.exec();
}
