#include "csengine.h"
#include <QDebug>


CsEngine::CsEngine(char *csd)
{
    mStop=false;
    m_csd = csd;
    errorValue=0;
}


CsEngine::~CsEngine()
{
	stop();
	//free cs;

}



//Csound *CsEngine::getCsound() {return &cs;}

void CsEngine::run()
{

    //if ( open(m_csd)) {
    if ( cs.Compile(m_csd)) {
		qDebug()<<"Could not open csound file "<<m_csd;
        return;
    }
    CsoundPerformanceThread perfThread(&cs);
    perfThread.Play();

    // kas siin üldse performance threadi vaja? vt. soundcarpet v CsdPlayerQt

	QList <MYFLT> oldValue, free;
	MYFLT actionNeeded;
	oldValue <<  1 << 1 <<1; // perhaps there is better way to define an empty list;
	free <<  1 << 1 <<1;
	QString channel, actionChannel;
	while (!mStop  && perfThread.GetStatus() == 0 ) {
		usleep(10000);  // ? et ei teeks tööd kogu aeg
		actionNeeded = getChannel("actionNeeded");
		if (actionNeeded>=10) { // a voice has been idle for long time
			qDebug()<<"Action needed for voice "<< actionNeeded-10;
			emit doSomething(actionNeeded-10); // signal to wsserever to generate a random message or play an old one;
			setChannel("actionNeeded",0);
		}
		for (int i=0;i<3;i++) {
			channel = "free"+QString::number(i+1);

			free[i] = getChannel(channel);
			if (free[i]!=oldValue[i]) {
				//emit channelValue(i,free[i]); // TEST
				qDebug()<<"free "<<i<<" "<<free[i];
				if (free[i]==1) { // instruments has ended
					qDebug()<<"free "<<i<<" "<<free[i];
					emit sendNewPattern(i);
					//free[i]=0;
					//setChannel(channel,0); // for any case
				}
			}
			oldValue[i] = free[i];
		}
	}
    qDebug()<<"Stopping thread";
    perfThread.Stop();
    perfThread.Join();
    mStop=false; // luba uuesti käivitamine
}

void CsEngine::stop()
{
    // cs.Reset();  // ?kills Csound at all
    mStop = true;

}

QString CsEngine::getErrorString()  // probably not necessry
{
    return errorString;
}

int CsEngine::getErrorValue()
{
    return errorValue;
}


MYFLT CsEngine::getChannel(QString channel)
{
    //qDebug()<<"setChannel "<<channel<<" value: "<<value;
	return cs.GetChannel(channel.toLocal8Bit());
}

void CsEngine::handleMessage(QString message)
{
	// message format: 'pattern' name voice repeatNtimes afterNsquares steps: pitch_index11 pitch_index2
	qDebug()<<"Message in csound: "<<message;
	//vaja midagi nagu: 1) compileOrc( giMatrix[voice][0] = step1 etc fillarray )  2) ;schedule "playPattern",0,0,nTimes, afterNsquares

	if (message.startsWith("clear") || message.startsWith("mode")) {
		return;
	}
	QStringList messageParts = message.split(",");

	if (message.startsWith("heart")) {
		double heartRate =  (messageParts[1]=="-1") ? 60 : messageParts[1].toDouble(); // if value is -1 (no signal from HR monitor, set to 60 )
		setChannel("heartrate",heartRate);
		return;
	}

	// otherwise pattern message:
	QString voice = messageParts[2];
	QString repeatNtimes = messageParts[3];
	QString afterNSquares = messageParts[4];
	QString panOrSpeaker = messageParts[5];



    // prepare steps for compileOrc:
//	QString code = "";
//	for (int j=0, i=messageParts.indexOf("steps:")+1 ; i<messageParts.length(); i++, j++ ) { // statements to store steps into 2d array giMartix[voice][step]
//		code += "giMatrix["+voice+"]["+QString::number(j) + "] = " + messageParts[i] +  "\n";
//	}
//    QString instrument = "nstrnum(\"playPattern\")+"+QString::number((voice+1).toFloat()/10);  // add a fraction to every pattern
//	qDebug()<<instrument;
//	code += "\nschedule "+instrument + ",0,0," + repeatNtimes + "," + afterNSquares + "," + voice + "," + panOrSpeaker;
//	qDebug()<<"Message to compile: "<<code;
//    compileOrc(code);

    // METHOD 2 (compileOrc has now memory leak in Csound) - use event and table instead
    //create table and send to Csound
    MYFLT stepArray[16]; // make sure that is is defined in csd with thable number 99
    for (int j=0, i=messageParts.indexOf("steps:")+1 ; i<messageParts.length(); i++, j++ ) { // statements to store steps into 2d array giMartix[voice][step]
        stepArray[j]=	 messageParts[i].toDouble();
        //code += "giMatrix["+voice+"]["+QString::number(j) + "] = " + messageParts[i] +  "\n";
    }
    cs.TableCopyIn(90+voice.toInt(),stepArray);
    QString instrument = QString::number(4 + (voice.toInt()+1)/4); // 4.1 - for low voice, 4.2 vor medium, 4.3 high
    QString code = "i "+instrument + " 0 5 " + repeatNtimes + " " + afterNSquares + " " + voice + " " + panOrSpeaker;
    csEvent(code);
}

void CsEngine::compileOrc(QString code)
{

	//qDebug()<<"Code to compile: "<<code;
	QString message;
	errorValue =  cs.CompileOrc(code.toLocal8Bit());
	if ( errorValue )
		message = "Could not compile the code";
	else
		message = "OK";

}

void CsEngine::restart()
{
    stop(); // sets mStop true
    while (mStop) // run sets mStop false again when perftrhead has joined
        usleep(100000);
	start();
}

void CsEngine::handleChannelChange(QString channel, double value)
{
	setChannel(channel, (MYFLT) value);
}

void CsEngine::setChannel(QString channel, MYFLT value)
{
    //qDebug()<<"setChannel "<<channel<<" value: "<<value;
    cs.SetChannel(channel.toLocal8Bit(), value);
}

void CsEngine::csEvent(QString event_string)
{
    cs.InputMessage(event_string.toLocal8Bit());
}
