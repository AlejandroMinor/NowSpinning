// Quickshell.Io, the parts the widget uses: FileView and JsonAdapter for
// config.json (and the terminal skin's hostname), and Process.
#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QQmlParserStatus>
#include <QStringList>
#include <QTimer>

// A JSON object whose keys are the properties declared on it in QML. Read
// from its FileView's file, and written back to it with writeAdapter().
class JsonAdapter : public QObject {
    Q_OBJECT

public:
    using QObject::QObject;

    // Sets each declared property found in `json`; the rest keep their
    // value. False if it isn't a JSON object.
    bool deserialize(const QByteArray& json);
    QByteArray serialize() const;
};

class FileView : public QObject, public QQmlParserStatus {
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(bool printErrors MEMBER m_printErrors NOTIFY printErrorsChanged)
    Q_PROPERTY(bool watchChanges READ watchChanges WRITE setWatchChanges NOTIFY watchChangesChanged)
    Q_PROPERTY(bool blockLoading MEMBER m_blockLoading NOTIFY blockLoadingChanged)
    Q_PROPERTY(bool loaded READ isLoaded NOTIFY loadedChanged)
    Q_PROPERTY(JsonAdapter* adapter READ adapter WRITE setAdapter NOTIFY adapterChanged)
    Q_CLASSINFO("DefaultProperty", "adapter")

public:
    explicit FileView(QObject* parent = nullptr);

    void classBegin() override {}
    void componentComplete() override;

    QString path() const { return m_path; }
    void setPath(const QString& path);
    bool watchChanges() const { return m_watchChanges; }
    void setWatchChanges(bool watch);
    bool isLoaded() const { return m_loaded; }
    JsonAdapter* adapter() const { return m_adapter; }
    void setAdapter(JsonAdapter* adapter);

    Q_INVOKABLE QString text() const;
    Q_INVOKABLE void reload();
    Q_INVOKABLE void writeAdapter();
    Q_INVOKABLE void setText(const QString& text);

Q_SIGNALS:
    void pathChanged();
    void printErrorsChanged();
    void watchChangesChanged();
    void blockLoadingChanged();
    void loadedChanged();
    void adapterChanged();
    // The file changed on disk, by someone else. Call reload() to read it.
    void fileChanged();
    void loadFailed(int error);
    void saved();
    void saveFailed(int error);

private:
    void load();
    bool write(const QByteArray& bytes);
    void watch();
    void checkChanged();

    QString m_path;
    bool m_printErrors = true;
    bool m_watchChanges = false;
    bool m_blockLoading = false;
    bool m_complete = false;
    bool m_loaded = false;
    QByteArray m_bytes;
    QPointer<JsonAdapter> m_adapter;
    QFileSystemWatcher* m_watcher = nullptr;
    QTimer m_settle;
};

// Runs a program. On Windows the widget only starts one, `mkdir -p` for its
// config folder, which nowspinning.exe has made already; it fails quietly.
class Process : public QObject, public QQmlParserStatus {
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(bool running READ isRunning WRITE setRunning NOTIFY runningChanged)
    Q_PROPERTY(QStringList command READ command WRITE setCommand NOTIFY commandChanged)
    Q_PROPERTY(QString workingDirectory MEMBER m_workingDirectory NOTIFY workingDirectoryChanged)

public:
    explicit Process(QObject* parent = nullptr);

    void classBegin() override {}
    void componentComplete() override;

    bool isRunning() const { return m_running; }
    void setRunning(bool running);
    QStringList command() const { return m_command; }
    void setCommand(const QStringList& command);

Q_SIGNALS:
    void runningChanged();
    void commandChanged();
    void workingDirectoryChanged();
    void started();
    void exited(int exitCode, int exitStatus);

private:
    void apply();

    QProcess m_process;
    bool m_complete = false;
    bool m_running = false;
    QStringList m_command;
    QString m_workingDirectory;
};
