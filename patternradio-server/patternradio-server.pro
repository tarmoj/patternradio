#-------------------------------------------------
#
# Project created by QtCreator 2015-02-18T16:51:32
#
#-------------------------------------------------

QT       += core websockets

QT       -= gui

TARGET = patternradio-server
CONFIG   += console
CONFIG   -= app_bundle

TEMPLATE = app


SOURCES += main.cpp \
    csengine.cpp \
    wsserver.cpp

HEADERS += \
    csengine.h \
    wsserver.h

LIBS += -lcsound64  -lcsnd6
