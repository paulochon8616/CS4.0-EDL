# -*- coding: utf-8 -*-
#
#-------------------------------------------------------------------------------
#
#     This file is part of the Code_Saturne User Interface, element of the
#     Code_Saturne CFD tool.
#
#     Copyright (C) 1998-2010 EDF S.A., France
#
#     contact: saturne-support@edf.fr
#
#     The Code_Saturne User Interface is free software; you can redistribute it
#     and/or modify it under the terms of the GNU General Public License
#     as published by the Free Software Foundation; either version 2 of
#     the License, or (at your option) any later version.
#
#     The Code_Saturne User Interface is distributed in the hope that it will be
#     useful, but WITHOUT ANY WARRANTY; without even the implied warranty
#     of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with the Code_Saturne Kernel; if not, write to the
#     Free Software Foundation, Inc.,
#     51 Franklin St, Fifth Floor,
#     Boston, MA  02110-1301  USA
#
#-------------------------------------------------------------------------------

"""
Command Manager
===============
Generic Dialog window to handle execution of a list of external scripts.
"""

#-------------------------------------------------------------------------------
# Standard modules
#-------------------------------------------------------------------------------

import os, string, logging
import signal, subprocess

#-------------------------------------------------------------------------------
# Third-party modules
#-------------------------------------------------------------------------------

from PyQt4.QtCore import *
from PyQt4.QtGui  import *

#-------------------------------------------------------------------------------
# Application modules
#-------------------------------------------------------------------------------

from CommandMgrDialogForm import Ui_CommandMgrDialogForm
from CommandMgrLinesDisplayedDialogForm import Ui_CommandMgrLinesDisplayedDialogForm
from QtPage import IntValidator, from_qvariant, to_text_string

#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger("CommandMgr")
log.setLevel(logging.NOTSET)

#-------------------------------------------------------------------------------
#
#-------------------------------------------------------------------------------

class CommandMgrLinesDisplayedDialogView(QDialog, Ui_CommandMgrLinesDisplayedDialogForm):
    """
    Advanced dialog for the control of the number
    of lines displayed in the QTextEdit.
    """
    def __init__(self, parent, default):
        """
        Constructor
        """
        QDialog.__init__(self, parent)

        Ui_CommandMgrLinesDisplayedDialogForm.__init__(self)
        self.setupUi(self)

        self.setWindowTitle(self.tr("Number of lines displayed"))

        self.default = default
        self.result  = self.default.copy()

        v = IntValidator(self.lineEditLines, min=0)
        self.lineEditLines.setValidator(v)

        # Previous values
        self.lines = self.default['lines']
        self.lineEditLines.setText(str(self.lines))

        self.connect(self.lineEditLines,
                     SIGNAL("textChanged(const QString &)"),
                     self.__slotLines)
        self.connect(self.pushButtonLines,
                     SIGNAL("clicked()"),
                     self.__slotUnlimited)


    @pyqtSignature("const QString &")
    def __slotLines(self, text):
        """
        Private slot. Manage the number of lines allowed in the display zone.
        """
        lines = from_qvariant(text, int)
        if self.sender().validator().state == QValidator.Acceptable:
            self.lines = lines


    @pyqtSignature("")
    def __slotUnlimited(self):
        """
        Private slot. Set a unlimited number of lines in the display zone.
        """
        self.lines = 0
        self.lineEditLines.setText(str(self.lines))


    def get_result(self):
        """
        Method to get the result
        """
        return self.result


    def accept(self):
        """
        Method called when user clicks 'OK'
        """
        self.result['lines'] = self.lines
        QDialog.accept(self)


    def reject(self):
        """
        Method called when user clicks 'Cancel'
        """
        QDialog.reject(self)

#-------------------------------------------------------------------------------
#
#-------------------------------------------------------------------------------

class CommandMgrDialogView(QDialog, Ui_CommandMgrDialogForm):
    """
    Open a dialog to start external programs and display its output.
    """
    def __init__(self, parent, title, cmd, start_directory="", obj_salome=""):
        """
        Constructor. Must be overriden.
        """
        QDialog.__init__(self, parent)

        Ui_CommandMgrDialogForm.__init__(self)
        self.setupUi(self)
        self.setWindowTitle(title)
        self.setWindowModality(Qt.NonModal)
        self.setModal(False)
        self.pushButtonOK.setEnabled(False)

        self.log = "listing"
        self.saveLog = "%ss (%s.*);;All files (*)" % (self.log, self.log)

        self.proc = QProcess()
        if start_directory != None and start_directory != "":
            self.proc.setWorkingDirectory(start_directory)

        self.objBr = obj_salome

        self.connect(self.proc,
                     SIGNAL('readyReadStandardOutput()'),
                     self.slotReadFromStdout)
        self.connect(self.proc,
                     SIGNAL('readyReadStandardError()'),
                     self.slotReadFromStderr)
        self.connect(self.pushButtonLines,
                     SIGNAL('clicked()'),
                     self.__slotLines)
        self.connect(self.pushButtonSaveAs,
                     SIGNAL('clicked()'),
                     self.__slotSaveAs)
        self.connect(self.pushButtonKill,
                     SIGNAL('clicked()'),
                     self.__slotKill)
        self.connect(self.proc,
                     SIGNAL('started()'),
                     self.slotStarted)
        self.connect(self.proc,
                     SIGNAL('finished(int, QProcess::ExitStatus)'),
                     self.slotFinished)

        self.cmd = cmd

        cursor = QCursor(Qt.BusyCursor)
        QApplication.setOverrideCursor(cursor)


    @pyqtSignature("int, QProcess::ExitStatus")
    def slotStarted(self):
        """
        Public slot. Process is started.
        """
        pass


    @pyqtSignature("int, QProcess::ExitStatus")
    def slotFinished(self, exitCode, exitStatus):
        """
        Public slot. Enable the close button of the dialog window.
        """

        if exitStatus != QProcess.NormalExit:
            error = self.proc.error()
            if error == QProcess.FailedToStart:
                print("failed to start")
            elif error == QProcess.Timedout:
                print("timed out")
            elif error == QProcess.WriteError:
                print("error trying to write to process")
            elif error == QProcess.ReadError:
                print("error trying to read from process")
            else:
                print("crashed or killed")

        # if the GUI is launched through SALOME, update the object browser
        # in order to display results
        if self.objBr:
            try:
                import CFDSTUDYGUI_DataModel
                r = CFDSTUDYGUI_DataModel.ScanChildren(self.objBr, "^RESU$")
                CFDSTUDYGUI_DataModel.UpdateSubTree(r[0])
            except:
                pass

        QApplication.restoreOverrideCursor()
        self.pushButtonOK.setEnabled(True)


    @pyqtSignature("")
    def __slotLines(self):
        """
        Private slot. Manage the number of lines allowed in the display zone.
        """
        default = {}
        default['lines'] = self.logText.document().maximumBlockCount()
        dlg = CommandMgrLinesDisplayedDialogView(self, default)
        if dlg.exec_():
            result = dlg.get_result()
            n = int(result['lines'])
            if n != default['lines']:
                self.logText.document().setMaximumBlockCount(n)


    @pyqtSignature("")
    def __slotKill(self):
        """
        Private slot. Kill the subprocess.
        """
        if self.proc.state() == QProcess.NotRunning:
            QMessageBox.warning(self,
                                self.tr('Error'),
                                self.tr('The process is not running.'))
            return

        r = QMessageBox.question(self,
                                 self.tr("Kill"),
                                 self.tr("Kill the process "),
                                 QMessageBox.Yes|QMessageBox.No)

        if r == QMessageBox.Yes:
            self.__killChildren()
            self.proc.kill()


    def __killChildren(self):
        """
        Private slot. Find and kill all children of the spawned subprocess.
        """
        cmd = "ps eo pid,ppid --sort=pid --no-headers"
        psraw = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE).stdout.readlines()
        psList = []
        killList = []

        for ps in psraw:
            psList.append(list(map(int, ps.split())))

        for ps in psList:
            if int(self.proc.pid()) == ps[1]:
                killList.append(ps[0])

        for ps in psList:
            if ps[1] in killList:
                killList.append(ps[0])

        if len(killList) <= 0:
            return

        cmd = "kill -9 %s" % " ".join(list(map(str, killList)))
        subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)


    @pyqtSignature("")
    def __slotSaveAs(self):
        """
        Private slot. Save the contain of the display zone.
        """
        if hasattr(self, 'suffix'):
            l = self.log + "." + self.suffix
        else:
            l = self.log

        f = os.path.join(self.case['resu_path'], l)

        fileName = QFileDialog.getSaveFileName(self,
                                               self.tr("Save log"),
                                               f,
                                               self.saveLog)
        if not fileName:
            return

        try:
            logFile = open(str(fileName), 'w')
        except:
            QMessageBox.warning(self, self.tr('Error'), self.tr('Could not open file for writing'))
            return

        logFile.write(self.logText.toPlainText().encode("utf-8"))
        logFile.close()


    @pyqtSignature("")
    def slotReadFromStdout(self):
        """
        Public slot. Handle the readyReadStandardOutput signal of the subprocess.
        """
        if self.proc is None:
            return
        self.proc.setReadChannel(QProcess.StandardOutput)

        while self.proc and self.proc.canReadLine():
            ba = self.proc.readLine()
            if ba.isNull(): return
            s = (ba.data()).decode("utf-8")[:-1]
            self.logText.append(s)


    @pyqtSignature("")
    def slotReadFromStderr(self):
        """
        Public slot. Handle the readyReadStandardError signal of the subprocess.
        """
        if self.proc is None:
            return
        self.proc.setReadChannel(QProcess.StandardError)

        while self.proc and self.proc.canReadLine():
            ba = self.proc.readLine()
            if ba.isNull(): return
            s = (ba.data()).decode("utf-8")[:-1]
            self.logText.append('<font color="red">' + s + '</font>')


    def closeEvent(self, event):
        """
        Public Method. Close the Dialog window.
        """
        self.__slotKill()
        event.accept()


    def tr(self, text):
        """
        Public Method. Translation.
        """
        return text

#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
