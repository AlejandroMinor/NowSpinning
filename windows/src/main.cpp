// nowspinning.exe: the widget on Windows.
//
// Like the `nowspinning` command on Linux it's a toggle: run while the
// widget is up, it closes it instead of opening a second one. `--quit`
// only closes it, for the installer.
//
// It runs the same QML as on Linux, from the nowspinning folder next to
// it, or NOWSPINNING_DIR. The settings live in %APPDATA%\nowspinning\config.json,
// or NOWSPINNING_CONFIG_DIR, and what it logs goes to nowspinning.log in
// %LOCALAPPDATA%\nowspinning, a fresh one on each start.
#include "host.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QLocalServer>
#include <QLocalSocket>
#include <QMutex>
#include <QQmlApplicationEngine>
#include <QQmlFileSelector>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QTextStream>
#include <QUrl>

#include <cstdio>

namespace {

QFile* logFile = nullptr;
QMutex logMutex;

void logMessage(QtMsgType type, const QMessageLogContext& context, const QString& message) {
    const QString line = qFormatLogMessage(type, context, message);
    QMutexLocker lock(&logMutex);
    if (logFile) {
        logFile->write(line.toUtf8());
        logFile->write("\n");
        logFile->flush();
    }
    std::fprintf(stderr, "%s\n", line.toLocal8Bit().constData());
    std::fflush(stderr);
}

void startLog() {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/nowspinning");
    QDir().mkpath(dir);
    logFile = new QFile(dir + QStringLiteral("/nowspinning.log"));
    if (!logFile->open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        delete logFile;
        logFile = nullptr;
    }
    qSetMessagePattern(QStringLiteral("%{time hh:mm:ss.zzz} %{if-warning}warning: %{endif}"
                                      "%{if-critical}error: %{endif}%{if-fatal}fatal: %{endif}%{message}"));
    qInstallMessageHandler(logMessage);
}

// Where the settings live: NOWSPINNING_CONFIG_DIR if set, as on Linux, or
// else %APPDATA%\nowspinning. Handed to the QML through the same variable.
QString configDir() {
    QString dir = qEnvironmentVariable("NOWSPINNING_CONFIG_DIR");
    if (dir.isEmpty()) {
#ifdef Q_OS_WIN
        dir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
            + QStringLiteral("/nowspinning");
        // GenericConfigLocation is %LOCALAPPDATA%; settings belong in the
        // roaming %APPDATA%.
        const QString roaming = qEnvironmentVariable("APPDATA");
        if (!roaming.isEmpty())
            dir = QDir::fromNativeSeparators(roaming) + QStringLiteral("/nowspinning");
#else
        dir = QDir::homePath() + QStringLiteral("/.config/nowspinning");
#endif
    }
    dir = QDir::fromNativeSeparators(dir);
    QDir().mkpath(dir);
    qputenv("NOWSPINNING_CONFIG_DIR", dir.toUtf8());
    return dir;
}

// The widget's QML: NOWSPINNING_DIR, or the nowspinning folder next to the
// program, or in a clone, the one at the top of it.
QString shellDir() {
    const QString given = qEnvironmentVariable("NOWSPINNING_DIR");
    if (!given.isEmpty())
        return QDir::fromNativeSeparators(given);

    QDir dir(QCoreApplication::applicationDirPath());
    for (int up = 0; up < 6; up++) {
        if (QFileInfo::exists(dir.filePath(QStringLiteral("nowspinning/shell.qml"))))
            return dir.filePath(QStringLiteral("nowspinning"));
        if (!dir.cdUp())
            break;
    }
    return QCoreApplication::applicationDirPath() + QStringLiteral("/nowspinning");
}

// One widget per settings folder, as `qs -p` keeps one per config on Linux.
QString instanceName(const QString& config) {
    const QByteArray key = QDir::cleanPath(config).toLower().toUtf8() + '\n' + qgetenv("USERNAME") + qgetenv("USER");
    return QStringLiteral("nowspinning-")
        + QString::fromLatin1(QCryptographicHash::hash(key, QCryptographicHash::Sha1).toHex().left(12));
}

// Asks a widget already running to close. True if there was one.
bool closeRunning(const QString& name) {
    QLocalSocket socket;
    socket.connectToServer(name);
    if (!socket.waitForConnected(500))
        return false;
    socket.write("quit\n");
    socket.waitForBytesWritten(500);
    socket.waitForDisconnected(2000);
    return true;
}

} // namespace

int main(int argc, char* argv[]) {
    // The widget draws on a see-through window.
    QQuickWindow::setDefaultAlphaBuffer(true);
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("nowspinning"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("NowSpinning"));
    QGuiApplication::setApplicationVersion(QStringLiteral(NOWSPINNING_VERSION));
    QGuiApplication::setDesktopFileName(QStringLiteral("nowspinning"));
    // Its windows come and go (moving to another monitor takes it down for
    // a beat): only Qt.quit(), or a second start, ends it.
    QGuiApplication::setQuitOnLastWindowClosed(false);

    const QStringList args = app.arguments();
    const bool onlyQuit = args.contains(QStringLiteral("--quit"));

    const QString config = configDir();
    const QString name = instanceName(config);
    if (closeRunning(name) || onlyQuit)
        return 0;

    startLog();
    qInfo().noquote() << "NowSpinning" << NOWSPINNING_VERSION << "on" << QSysInfo::prettyProductName()
                      << "with Qt" << qVersion();

    QLocalServer::removeServer(name);
    QLocalServer server;
    server.setSocketOptions(QLocalServer::UserAccessOption);
    if (!server.listen(name))
        qWarning().noquote() << "Can't listen for a second start:" << server.errorString();
    QObject::connect(&server, &QLocalServer::newConnection, &app, [&server] {
        while (QLocalSocket* socket = server.nextPendingConnection()) {
            QObject::connect(socket, &QLocalSocket::readyRead, socket, [socket] {
                if (socket->readAll().contains("quit")) {
                    socket->disconnectFromServer();
                    QCoreApplication::quit();
                }
            });
            QObject::connect(socket, &QLocalSocket::disconnected, socket, &QObject::deleteLater);
        }
    });

    Host::registerTypes();

    QQmlApplicationEngine engine;
    // nowspinning/+windows holds what replaces the Linux-only QML files
    // (cava, Hyprland's cursor): Qt picks those in their place. Named for
    // Windows; set elsewhere too, so the same files run when trying it out.
    auto* selector = new QQmlFileSelector(&engine, &engine);
    selector->setExtraSelectors({QStringLiteral("windows")});
    QObject::connect(&engine, &QQmlApplicationEngine::quit, &app, &QCoreApplication::quit, Qt::QueuedConnection);

    const QString dir = shellDir();
    const QString shell = dir + QStringLiteral("/shell.qml");
    qInfo().noquote() << "Widget:" << QDir::toNativeSeparators(shell);
    qInfo().noquote() << "Settings:" << QDir::toNativeSeparators(config + QStringLiteral("/config.json"));
    if (!QFileInfo::exists(shell)) {
        qCritical().noquote() << "No widget at" << QDir::toNativeSeparators(shell);
        return 1;
    }

    engine.load(QUrl::fromLocalFile(shell));
    if (engine.rootObjects().isEmpty()) {
        qCritical() << "The widget failed to load";
        return 1;
    }
    return app.exec();
}
