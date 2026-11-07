#include "io.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaProperty>
#include <QSaveFile>
#include <QtDebug>

bool JsonAdapter::deserialize(const QByteArray& json) {
    QByteArray bytes = json;
    // Notepad and others save UTF-8 with a byte order mark, which
    // QJsonDocument doesn't skip on its own.
    if (bytes.startsWith("\xEF\xBB\xBF"))
        bytes.remove(0, 3);

    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(bytes, &error);
    if (!document.isObject())
        return false;
    const QJsonObject object = document.object();

    const QMetaObject* meta = metaObject();
    for (int i = JsonAdapter::staticMetaObject.propertyCount(); i < meta->propertyCount(); i++) {
        const QMetaProperty property = meta->property(i);
        const QString name = QString::fromLatin1(property.name());
        if (!object.contains(name) || !property.isWritable())
            continue;
        QVariant value = object.value(name).toVariant();
        if (property.metaType().id() != QMetaType::QVariant && !value.convert(property.metaType()))
            continue;
        if (property.read(this) != value)
            property.write(this, value);
    }
    return true;
}

QByteArray JsonAdapter::serialize() const {
    QJsonObject object;
    const QMetaObject* meta = metaObject();
    for (int i = JsonAdapter::staticMetaObject.propertyCount(); i < meta->propertyCount(); i++) {
        const QMetaProperty property = meta->property(i);
        object.insert(QString::fromLatin1(property.name()), QJsonValue::fromVariant(property.read(this)));
    }
    return QJsonDocument(object).toJson(QJsonDocument::Indented);
}

FileView::FileView(QObject* parent)
    : QObject(parent) {
    // Editors save in steps (a temporary file, then a rename): read it once
    // they're done.
    m_settle.setSingleShot(true);
    m_settle.setInterval(50);
    connect(&m_settle, &QTimer::timeout, this, &FileView::checkChanged);
}

void FileView::componentComplete() {
    m_complete = true;
    load();
    watch();
}

void FileView::setPath(const QString& path) {
    if (path == m_path)
        return;
    m_path = path;
    Q_EMIT pathChanged();
    if (m_complete) {
        load();
        watch();
    }
}

void FileView::setWatchChanges(bool watch) {
    if (watch == m_watchChanges)
        return;
    m_watchChanges = watch;
    Q_EMIT watchChangesChanged();
    if (m_complete)
        this->watch();
}

void FileView::setAdapter(JsonAdapter* adapter) {
    if (adapter == m_adapter)
        return;
    m_adapter = adapter;
    if (m_complete && m_adapter && m_loaded)
        m_adapter->deserialize(m_bytes);
    Q_EMIT adapterChanged();
}

QString FileView::text() const {
    return QString::fromUtf8(m_bytes);
}

void FileView::reload() {
    load();
}

void FileView::load() {
    const bool wasLoaded = m_loaded;
    QFile file(m_path);
    if (m_path.isEmpty() || !file.open(QIODevice::ReadOnly)) {
        m_bytes.clear();
        m_loaded = false;
        if (m_printErrors && !m_path.isEmpty())
            qWarning().noquote() << "FileView: cannot read" << m_path << ":" << file.errorString();
        if (wasLoaded)
            Q_EMIT loadedChanged();
        Q_EMIT loadFailed(int(file.error()));
        return;
    }
    m_bytes = file.readAll();
    m_loaded = true;
    if (m_adapter && !m_adapter->deserialize(m_bytes) && m_printErrors)
        qWarning().noquote() << "FileView: not a JSON object:" << m_path;
    if (!wasLoaded)
        Q_EMIT loadedChanged();
}

void FileView::setText(const QString& text) {
    write(text.toUtf8());
}

void FileView::writeAdapter() {
    if (m_adapter)
        write(m_adapter->serialize());
}

bool FileView::write(const QByteArray& bytes) {
    if (m_path.isEmpty())
        return false;
    QDir().mkpath(QFileInfo(m_path).absolutePath());

    QSaveFile file(m_path);
    // Where the file can't be replaced (an antivirus or an editor holding
    // it), write it in place instead.
    file.setDirectWriteFallback(true);
    if (!file.open(QIODevice::WriteOnly) || file.write(bytes) != bytes.size() || !file.commit()) {
        if (m_printErrors)
            qWarning().noquote() << "FileView: cannot write" << m_path << ":" << file.errorString();
        Q_EMIT saveFailed(int(file.error()));
        return false;
    }
    // Known already: the watcher's own news of it isn't a change.
    m_bytes = bytes;
    const bool wasLoaded = m_loaded;
    m_loaded = true;
    if (!wasLoaded)
        Q_EMIT loadedChanged();
    watch();
    Q_EMIT saved();
    return true;
}

void FileView::watch() {
    if (!m_watchChanges || m_path.isEmpty()) {
        delete m_watcher;
        m_watcher = nullptr;
        return;
    }
    if (!m_watcher) {
        m_watcher = new QFileSystemWatcher(this);
        connect(m_watcher, &QFileSystemWatcher::fileChanged, &m_settle, qOverload<>(&QTimer::start));
        connect(m_watcher, &QFileSystemWatcher::directoryChanged, &m_settle, qOverload<>(&QTimer::start));
    }
    const QString dir = QFileInfo(m_path).absolutePath();
    QStringList wanted{dir};
    if (QFile::exists(m_path))
        wanted.append(m_path);
    // A file replaced by a rename drops out of the watcher: watch it again.
    for (const QString& path : wanted) {
        if (!m_watcher->files().contains(path) && !m_watcher->directories().contains(path))
            m_watcher->addPath(path);
    }
}

void FileView::checkChanged() {
    watch();
    QFile file(m_path);
    QByteArray bytes;
    if (file.open(QIODevice::ReadOnly))
        bytes = file.readAll();
    else if (!m_loaded)
        return;
    if (bytes != m_bytes)
        Q_EMIT fileChanged();
}

Process::Process(QObject* parent)
    : QObject(parent) {
    connect(&m_process, &QProcess::started, this, &Process::started);
    connect(&m_process, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        m_running = false;
        Q_EMIT exited(code, int(status));
        Q_EMIT runningChanged();
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart && m_running) {
            m_running = false;
            Q_EMIT runningChanged();
        }
    });
}

void Process::componentComplete() {
    m_complete = true;
    apply();
}

void Process::setRunning(bool running) {
    if (running == m_running)
        return;
    m_running = running;
    Q_EMIT runningChanged();
    apply();
}

void Process::setCommand(const QStringList& command) {
    if (command == m_command)
        return;
    m_command = command;
    Q_EMIT commandChanged();
}

void Process::apply() {
    if (!m_complete)
        return;
    if (m_running && m_process.state() == QProcess::NotRunning && !m_command.isEmpty()) {
        if (!m_workingDirectory.isEmpty())
            m_process.setWorkingDirectory(m_workingDirectory);
        m_process.start(m_command.first(), m_command.mid(1));
    } else if (!m_running && m_process.state() != QProcess::NotRunning) {
        m_process.kill();
    }
}
