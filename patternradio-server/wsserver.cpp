#include "wsserver.h"
#include "QtWebSockets/qwebsocketserver.h"
#include "QtWebSockets/qwebsocket.h"
#include <QtCore/QDebug>
#include <QFile>
#include <QDateTime>

QT_USE_NAMESPACE
#define LOGFILE "pattern-messages.log"


WsServer::WsServer(quint16 port, QObject *parent) :
    QObject(parent),
	m_pWebSocketServer(new QWebSocketServer(QStringLiteral("PatternServer"),
                                            QWebSocketServer::NonSecureMode, this)),
    m_clients()
{
    if (m_pWebSocketServer->listen(QHostAddress::Any, port)) {
        qDebug() << "WsServer listening on port" << port;
        connect(m_pWebSocketServer, &QWebSocketServer::newConnection,
                this, &WsServer::onNewConnection);
        connect(m_pWebSocketServer, &QWebSocketServer::closed, this, &WsServer::closed);
    }
	patternQue << QStringList() << QStringList()<<QStringList(); // define the list
    oldPatterns << QStringList() << QStringList()<<QStringList();
    names << QStringList() << QStringList()<<QStringList();
	freeToPlay<<1<<1<<1;
    modeNames<<"Slendro"<<"Pelog"<<"Bohlen-Pierce"; // not necessary in radio
	mode = 0;
    // fill list oldPatterns from log file on startup
    QFile logFile(LOGFILE);
    if (logFile.open(QIODevice::ReadOnly| QIODevice::Text)) {
        QTextStream in(&logFile);
        QString line = in.readLine().simplified();
        while (!line.isNull()) {
            if (line.startsWith("pattern")) {
                int voice = line.split(",")[2].toInt();
                oldPatterns[voice].append(line);
            }
            line = in.readLine().simplified();
        }
        logFile.close();
    } else
        qDebug()<<"Could not open logfile "<<LOGFILE;
}


WsServer::~WsServer()
{
    m_pWebSocketServer->close();
    qDeleteAll(m_clients.begin(), m_clients.end());
}


void WsServer::onNewConnection()
{
    QWebSocket *pSocket = m_pWebSocketServer->nextPendingConnection();

    connect(pSocket, &QWebSocket::textMessageReceived, this, &WsServer::processTextMessage);
    //connect(pSocket, &QWebSocket::binaryMessageReceived, this, &WsServer::processBinaryMessage);
    connect(pSocket, &QWebSocket::disconnected, this, &WsServer::socketDisconnected);

    m_clients << pSocket;
    emit newConnection(m_clients.count());
	qDebug()<<"New connection, clients count: "<< m_clients.count();
	pSocket->sendTextMessage("mode,"+QString::number(mode)); // to set the active mode on connect
}

int randInt(int low, int high) {
	return qrand() % ((high + 1) - low) + low;
}

void WsServer::processTextMessage(QString message)
{
//    QWebSocket *pClient = qobject_cast<QWebSocket *>(sender());
//    if (!pClient) {
//        return;
//    } // - don't need info about client
	qDebug()<<message;

	QStringList messageParts = message.split(",");


	if (message.startsWith("monitor")) { // signals server that this is UI page, send new patterns etc there.
		QWebSocket *pClient = qobject_cast<QWebSocket *>(sender());
		if (!pClient) {
				return;
		}
		m_monitors.append(pClient);
		qDebug()<<"New monitor connected";
		pClient->sendTextMessage("Hi!");
	}

	if (message.startsWith("random")) { // create random pattern, add to que format: random,<voice>
		int voice = messageParts[1].toInt();
		QString steps="";
		QList <int> stepCount;
		stepCount<<6<<8<<10;
		for (int i=0;i<stepCount[mode];i++)  { // pattern length depends on mode
			steps+=","+QString::number(randInt(-1,stepCount[mode]-1));
		}
		QString pattern;
		pattern.sprintf("pattern,tester%d,%d,%d,%d,%d,steps:",randInt(1,100),voice, randInt(0,5),randInt(2,6), randInt(1,8));
		pattern += steps;
		qDebug()<<"Generated random pattern for voice "<<voice<<": "<<pattern;
		message=pattern; // replace message for further processing
		messageParts = message.split(",");
	}


	// pattern-message format: 'pattern' name voice repeatNtimes afterNsquares steps: pitch_index11 pitch_index2
	if (message.startsWith("pattern")) {
		int voice = messageParts[2].toInt();
        //TODO: if startswith patternOLD, mark in name OLD
		patternQue[voice].append(message);
        QString name = (messageParts[0].contains("OLD")) ? messageParts[1] + " (old)" : messageParts[1]; // DOES NOT WORK YET!
        names[voice].append(name); // store names to list
		//emit namesChanged(voice, names[voice].join("\n"));
		sendToMonitors("names,"+messageParts[2]+","+names[voice].join("\n"));
        qDebug()<<"New pattern from "<< name << message;
		qDebug()<<"Messages in list per voice: "<<voice<<": "<<patternQue[voice].count();


        //LOG - append every new pattern to file

        if (!messageParts[0].contains("OLD")) {
            oldPatterns[voice].append(message);
            QFile logFile(LOGFILE);
            if (logFile.open(QIODevice::Append)) {
                logFile.write(QDateTime::currentDateTime().toString("dd.MM.yy hh:mm:ss").toLocal8Bit()+"\n");
                //TODO: add country from IP
                logFile.write("\t"+message.toLocal8Bit()+"\n");
                logFile.close();
            } else
                qDebug()<<"Could not open logfile "<<LOGFILE;
        }

		if (freeToPlay[voice]) {
			sendFirstMessage(voice);
		}

	} else 	if (message.startsWith("new")) { // for testing only. send message from js console of browser wit doSend("new 1") or similar
		int voice = messageParts[1].toInt();
		freeToPlay[voice]=1;
		sendFirstMessage(voice);
		//emit newCodeToComplie("gkLevel["+QString::number(voice)+"] init 0"); // also tell csound that new pattern can be started

	} else if (message.startsWith("property")) {
	// send control messages either for brain-headset or csound cahnnels as f.e. "property,attention,0.25", "property,level,0.5"

		emit newPropertyValue(messageParts[1], messageParts[2].toDouble());

	} else if (message.startsWith("square")) { // command to change square duration: squareDuration voice duration. Send to csound as code for compileOrc
		int voice = messageParts[1].toInt();
		float duration = messageParts[2].toFloat();
		qDebug()<<"Voice "<<voice<<" New square duration: "<<duration;
		emit newPropertyValue("square"+QString::number(voice+1), messageParts[2].toDouble()); // set via channel
		emit newSquare(voice, duration);

		//TODO: squareDuration to PatternRect

	} else if (message.startsWith("schedule") || message.contains("init")) { //right now only schedule or init commands are accepted
		emit newCodeToComplie(message);
		if (message.contains("setMode"))  {
				mode = messageParts[3].toInt();
				emit newMessage("mode,"+modeNames[mode]); // bit cryptic code, should extract the scale and forward to qml
				foreach (QWebSocket * client, m_clients) {
					client->sendTextMessage("mode,"+messageParts[3]); // tell the clients about mode change
				}
		}

	} else if (message.startsWith("clear")) {
		int voice = messageParts[1].toInt();
		patternQue[voice].clear();
		names[voice].clear();
		sendFirstMessage(voice); // to emit siganl to qml to clear
	}



}

//void WsServer::processBinaryMessage(QByteArray message)
//{
//    QWebSocket *pClient = qobject_cast<QWebSocket *>(sender());
//    if (pClient) {
//        pClient->sendBinaryMessage(message);
//    }
//}

void WsServer::socketDisconnected()
{
    QWebSocket *pClient = qobject_cast<QWebSocket *>(sender());
    if (pClient) {
        m_clients.removeAll(pClient);
		if (m_monitors.contains(pClient))
			m_monitors.removeAll(pClient);
        emit newConnection(m_clients.count());
        pClient->deleteLater();
	}
}

void WsServer::sendToMonitors(QString message)
{
	foreach (QWebSocket *socket, m_monitors) {
		socket->sendTextMessage(message);
	}
}


void WsServer::sendMessage(QWebSocket *socket, QString message )
{
    if (socket == 0)
    {
        return;
    }
    socket->sendTextMessage(message);

}

void WsServer::sendFirstMessage(int voice)
{
	if (!freeToPlay[voice]) {
		qDebug()<<"Voice "<<voice<<" is not free to play!";
		return;
	}

	if (voice>=patternQue.length() || voice<0)  {// for any case
		qDebug()<<"patternQue: "<<voice<<" Index out of range";
		return;
	}
	if (patternQue[voice].isEmpty()) {
		qDebug()<<"patternQue["<<voice<<"] is empty";
		//emit newMessage("clear,"+QString::number(voice));
		sendToMonitors("clear,"+QString::number(voice));
		return;
	}

	QString firstMessage = patternQue[voice].takeFirst();
	qDebug()<<"Messages in list per voice: "<<voice<<": "<<patternQue[voice].count();
	freeToPlay[voice]=0;
	emit newMessage(firstMessage);
	if (!names[voice].isEmpty())
		names[voice].removeFirst();
	//emit namesChanged(voice, names[voice].join("\n"));
	sendToMonitors("names,"+QString::number(voice)+","+names[voice].join("\n"));
	sendToMonitors(firstMessage);

}

void WsServer::setFreeToPlay(int voice)
{
	qDebug()<<"FREE TO PLAY "<<voice;
	freeToPlay[voice]=1;
	sendFirstMessage(voice);
}

void WsServer::cutTheSilence(int voice)  // called when there has been silence for long time in the voice
{
	setFreeToPlay(voice); // for any case
    //
    if (!oldPatterns[voice].isEmpty()) {
        QString pattern = oldPatterns[voice].takeFirst();
        //TODO: somehow add "OLD"
        if (!pattern.startsWith("patternOLD"))
            pattern.replace("pattern","patternOLD"); // to signal that it comes from the pool of old patterns
        oldPatterns[voice].append(pattern); // and put it to the end of queue
        processTextMessage(pattern);
    } else
        processTextMessage("random,"+QString::number(voice)); // generate a random pattern

}
