#include <QCoreApplication>
#include "wsserver.h"
#include "csengine.h"

int main(int argc, char *argv[])
{
	QCoreApplication a(argc, argv);

	WsServer *wsServer;
	wsServer = new WsServer(10010);
	CsEngine cs("../patterngame.csd");

	QObject::connect(wsServer,SIGNAL(newMessage(QString)),&cs,SLOT(handleMessage(QString)) );
	QObject::connect(&cs, SIGNAL(sendNewPattern(int)), wsServer, SLOT(setFreeToPlay(int)));
	QObject::connect(wsServer, SIGNAL(newPropertyValue(QString,double)), &cs, SLOT(handleChannelChange(QString,double)));
	QObject::connect(wsServer, SIGNAL(newCodeToComplie(QString)) , &cs, SLOT(compileOrc(QString)));


	cs.start();


	return a.exec();
}
