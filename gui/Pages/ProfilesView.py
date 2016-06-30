# -*- coding: utf-8 -*-

#-------------------------------------------------------------------------------

# This file is part of Code_Saturne, a general-purpose CFD tool.
#
# Copyright (C) 1998-2016 EDF S.A.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
# Street, Fifth Floor, Boston, MA 02110-1301, USA.

#-------------------------------------------------------------------------------

"""
This module defines the 'Meshes and Enveloppe' page.

This module contains the following classes:
- ProfilesView
"""

#-------------------------------------------------------------------------------
# Standard modules
#-------------------------------------------------------------------------------

import string
import logging

#-------------------------------------------------------------------------------
# Third-party modules
#-------------------------------------------------------------------------------

from PyQt4.QtCore import *
from PyQt4.QtGui  import *

#-------------------------------------------------------------------------------
# Application modules import
#-------------------------------------------------------------------------------

from code_saturne.Base.Common import LABEL_LENGTH_MAX
from code_saturne.Base.Toolbox import GuiParam
from code_saturne.Base.QtPage import IntValidator, DoubleValidator, RegExpValidator, ComboModel
from code_saturne.Base.QtPage import setGreenColor, to_qvariant, from_qvariant
from code_saturne.Pages.ProfilesForm import Ui_ProfilesForm
from code_saturne.Pages.ProfilesModel import ProfilesModel
from code_saturne.Pages.QMeiEditorView import QMeiEditorView

#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger("ProfilesView")
log.setLevel(GuiParam.DEBUG)

#-------------------------------------------------------------------------------
# StandarItemModel class
#-------------------------------------------------------------------------------

class StandardItemModelProfile(QStandardItemModel):

    def __init__(self):
        """
        """
        QStandardItemModel.__init__(self)
        self.setColumnCount(2)
        self.dataProfile = []


    def data(self, index, role):
        if not index.isValid():
            return to_qvariant()
        if role == Qt.DisplayRole:
            return to_qvariant(self.dataProfile[index.row()][index.column()])
        elif role == Qt.TextAlignmentRole:
            return to_qvariant(Qt.AlignCenter)
        return to_qvariant()


    def flags(self, index):
        if not index.isValid():
            return Qt.ItemIsEnabled
        else:
            return Qt.ItemIsEnabled | Qt.ItemIsSelectable


    def headerData(self, section, orientation, role):
        if orientation == Qt.Horizontal and role == Qt.DisplayRole:
            if section == 0:
                return to_qvariant(self.tr("Filename"))
            elif section == 1:
                return to_qvariant(self.tr("Variables"))
        elif role == Qt.TextAlignmentRole:
            return to_qvariant(Qt.AlignCenter)
        return to_qvariant()


    def setData(self, index, value, role):
        self.emit(SIGNAL("dataChanged(const QModelIndex &, const QModelIndex &)"), index, index)
        return True


    def addItem(self, label, prof):
        """
        Add a row in the table.
        """
        self.dataProfile.append([label, prof])
        row = self.rowCount()
        self.setRowCount(row+1)


    def replaceItem(self, row, label, prof):
        """
        Replace a row in the table.
        """
        self.dataProfile[row] = [label, prof]


    def deleteRow(self, row):
        """
        Delete the row in the model
        """
        del self.dataProfile[row]
        row = self.rowCount()
        self.setRowCount(row-1)


    def getItem(self, row):
        """
        Returns the name of the mesh file.
        """
        return self.dataProfile[row]


    def getLabel(self, row):
        """
        Returns the name of the mesh file.
        """
        return self.dataProfile[row][0]

#-------------------------------------------------------------------------------
# Main class
#-------------------------------------------------------------------------------

class ProfilesView(QWidget, Ui_ProfilesForm):
    """
    """
    def __init__(self, parent, case, stbar):
        """
        Constructor
        """
        QWidget.__init__(self, parent)

        Ui_ProfilesForm.__init__(self)
        self.setupUi(self)

        self.case = case
        self.case.undoStopGlobal()
        self.mdl = ProfilesModel(self.case)

        #  Initialize variables concerning the display of the Hlist

        self.entriesNumber = 0

        # Models
        self.modelProfile = StandardItemModelProfile()
        self.treeViewProfile.setModel(self.modelProfile)
        self.treeViewProfile.resizeColumnToContents(0)

        # QListView layout
        self.gridlayout1 = QGridLayout(self.widgetDrag)
        self.gridlayout1.setMargin(0)
        self.DragList = QListView(self.widgetDrag)
        self.gridlayout1.addWidget(self.DragList,0,0,1,1)

        self.gridlayout2 = QGridLayout(self.widgetDrop)
        self.gridlayout2.setMargin(0)
        self.DropList = QListView(self.widgetDrop)
        self.gridlayout2.addWidget(self.DropList,0,0,1,1)

        self.modelDrag = QStringListModel()
        self.modelDrop = QStringListModel()
        self.DragList.setModel(self.modelDrag)
        self.DropList.setModel(self.modelDrop)
        self.DragList.setAlternatingRowColors(True)
        self.DragList.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.DropList.setAlternatingRowColors(True)
        self.DropList.setEditTriggers(QAbstractItemView.NoEditTriggers)

        # Combo items
        self.modelFreq = ComboModel(self.comboBoxFreq, 3, 1)
        self.modelFreq.addItem(self.tr("at the end of the calculation"), "end")
        self.modelFreq.addItem(self.tr("at each 'n' time steps"), "frequency")
        self.modelFreq.addItem(self.tr("Output every 'x' seconds"), 'time_value')

        self.modelFormat = ComboModel(self.comboBoxFormat, 2, 1)
        self.modelFormat.addItem(self.tr(".dat"), "DAT")
        self.modelFormat.addItem(self.tr(".csv"), "CSV")

        # Connections
        self.connect(self.treeViewProfile,       SIGNAL("pressed(const QModelIndex &)"), self.slotSelectProfile)
        self.connect(self.pushButtonAdd,         SIGNAL("clicked()"), self.slotAddProfile)
        self.connect(self.pushButtonDelete,      SIGNAL("clicked()"), self.slotDeleteProfile)
        self.connect(self.pushButtonAddVar,      SIGNAL("clicked()"), self.slotAddVarProfile)
        self.connect(self.pushButtonSuppressVar, SIGNAL("clicked()"), self.slotDeleteVarProfile)
        self.connect(self.comboBoxFreq,          SIGNAL("activated(const QString&)"), self.slotFrequencyType)
        self.connect(self.comboBoxFormat,        SIGNAL("activated(const QString&)"), self.slotFormatType)
        self.connect(self.pushButtonFormula,     SIGNAL("clicked()"), self.slotFormula)
        self.connect(self.lineEditBaseName,      SIGNAL("textChanged(const QString &)"), self.slotBaseName)
        self.connect(self.lineEditTitle,         SIGNAL("textChanged(const QString &)"), self.slotTitle)
        self.connect(self.lineEditFreq,          SIGNAL("textChanged(const QString &)"), self.slotFrequence)
        self.connect(self.lineEditFreqTime,      SIGNAL("textChanged(const QString &)"), self.slotFrequenceTime)
        self.connect(self.lineEditNbPoint,       SIGNAL("textChanged(const QString &)"), self.slotNbPoint)

        # Validators
        validatorFreq = IntValidator(self.lineEditFreq, min=0)
        validatorFreq.setExclusiveMin(True)
        self.lineEditFreq.setValidator(validatorFreq)

        validatorFreqT = DoubleValidator(self.lineEditFreqTime, min=0.)
        validatorFreqT.setExclusiveMin(True)
        self.lineEditFreqTime.setValidator(validatorFreqT)

        validatorNbPoint = IntValidator(self.lineEditNbPoint, min=0)
        self.lineEditNbPoint.setValidator(validatorNbPoint)

        rx = "[\- _A-Za-z0-9]{1," + str(LABEL_LENGTH_MAX) + "}"
        validatorTitle =  RegExpValidator(self.lineEditTitle, QRegExp(rx))
        self.lineEditTitle.setValidator(validatorTitle)

        rx = "[\-_A-Za-z0-9]{1," + str(LABEL_LENGTH_MAX) + "}"
        validatorBaseName =  RegExpValidator(self.lineEditBaseName, QRegExp(rx))
        self.lineEditBaseName.setValidator(validatorBaseName)

        #update list of variables, properties, scalars ...
        liste_label = []
        for label in self.mdl.getVariablesAndVolumeProperties():
            liste_label.append(label)
        self.modelDrag.setStringList(sorted(liste_label, key=str.lower))

        #update list of profiles for view from xml file
        for lab in self.mdl.getProfilesLabelsList():
            self.entriesNumber = self.entriesNumber + 1
            label, title, fmt, lst, choice, freq, formula, nb_point = self.mdl.getProfileData(lab)
            self.__insertProfile(label, lst)

        self.__eraseEntries()

        self.case.undoStartGlobal()


    def __verifLabel(self):
        """
        Verif label.
        """
        label = str(self.lineEditBaseName.text())
        if label in self.mdl.getProfilesLabelsList():
            default = {}
            default['label'] = label
            default['list'] = self.mdl.getProfilesLabelsList()
            rx = "[\-_A-Za-z0-9]{1," + str(LABEL_LENGTH_MAX) + "}"
            default['regexp'] = QRegExp(rx)
            from code_saturne.Pages.VerifyExistenceLabelDialogView import VerifyExistenceLabelDialogView
            dialog = VerifyExistenceLabelDialogView(self, default)
            if dialog.exec_():
                result = dialog.get_result()
                label = result['label']
                if result['label'] == default['label']:
                    label = ""
        return label


    @pyqtSignature("const QString&")
    def slotFrequencyType(self, text):
        """
        Input choice for frequency for profile.
        """
        choice = self.modelFreq.dicoV2M[str(text)]

        if choice == "end":
            nfreq = -1
            self.lineEditFreq.setText(str(nfreq))
            self.lineEditFreq.show()
            self.lineEditFreqTime.hide()
            self.lineEditFreq.setDisabled(True)

        elif choice == "frequency":
            self.lineEditFreq.show()
            self.lineEditFreqTime.hide()
            nfreq = self.mdl.getOutputFrequency(self.label_select)
            if nfreq == -1:
                nfreq = 1
            self.lineEditFreq.setEnabled(True)
            self.lineEditFreq.setText(str(nfreq))

        elif choice == "time_value":
            self.lineEditFreq.hide()
            self.lineEditFreqTime.show()
            nfreq = self.mdl.getOutputFrequency(self.label_select)
            if nfreq == -1:
                nfreq = 1.0
            self.lineEditFreqTime.setText(str(nfreq))

        self.mdl.setOutputType(self.label_select, choice)
        self.mdl.setOutputFrequency(self.label_select, nfreq)


    @pyqtSignature("const QString&")
    def slotFormatType(self, text):
        """
        Input choice for frequency for profile.
        """
        fmt = self.modelFormat.dicoV2M[str(text)]
        self.mdl.setFormat(self.label_select, fmt)


    def __infoProfile(self, row):
        """
        Return info from the argument entry.
        """
        label = self.modelProfile.getLabel(row)
        lab, title, fmt, lst, choice, freq, formula, nb_point = self.mdl.getProfileData(label)
        return label, title, fmt, lst, choice, freq, formula, nb_point


    def __insertProfile(self, label, lst):
        """
        Insert values in table view.
        """
        self.modelProfile.addItem(label, " ; ".join(lst))


    @pyqtSignature("")
    def slotAddProfile(self):
        """
        Set in view label and variables to see on profile
        """
        var_prof = []
        label = self.mdl.addProfile()
        self.__insertProfile(label, var_prof)
        self.__eraseEntries()


    @pyqtSignature("")
    def slotDeleteProfile(self):
        """
        Delete the profile from the list (one by one).
        """
        row = self.treeViewProfile.currentIndex().row()
        log.debug("slotDeleteProfile -> %s" % (row,))
        if row == -1:
            title = self.tr("Warning")
            msg   = self.tr("You must select an existing profile")
            QMessageBox.information(self, title, msg)
        else:
            label, title, fmt, lst, choice, freq, formula, nb_point = self.__infoProfile(row)
            self.modelProfile.deleteRow(row)
            self.mdl.deleteProfile(label)
            self.__eraseEntries()


    @pyqtSignature("const QModelIndex &")
    def slotSelectProfile(self, index):
        """
        Return the selected item from the list.
        """
        self.groupBoxProfile.show()

        row = index.row()
        log.debug("slotSelectProfile -> %s" % (row,))

        label, title, fmt, liste, choice, freq, formula, nb_point = self.__infoProfile(row)
        self.label_select = label

        self.lineEditTitle.setText(str(title))
        self.lineEditBaseName.setText(str(label))
        self.modelFormat.setItem(str_model=fmt)

        self.modelFreq.setItem(str_model=choice)
        if choice == "end":
            self.lineEditFreq.show()
            self.lineEditFreqTime.hide()
            self.lineEditFreq.setText(str("-1"))
            self.lineEditFreq.setDisabled(True)

        elif choice == "frequency":
            self.lineEditFreq.show()
            self.lineEditFreqTime.hide()
            self.lineEditFreq.setEnabled(True)
            self.lineEditFreq.setText(str(freq))

        elif choice == "time_value":
            self.lineEditFreq.hide()
            self.lineEditFreqTime.show()
            self.lineEditFreqTime.setText(str(freq))

        self.lineEditNbPoint.setText(str(nb_point))

        self.modelDrop.setStringList([])
        liste = [str(s) for s in liste]

        self.modelDrop.setStringList(liste)

        setGreenColor(self.pushButtonFormula, True)


    @pyqtSignature("")
    def slotAddVarProfile(self):
        """
        Add a new var from list to profile
        """
        if (self.DragList.currentIndex().row() >=0) :
            liste = self.modelDrop.stringList()
            var = self.modelDrag.stringList()[self.DragList.currentIndex().row()]
            if var not in liste :
                liste.append(var)
            liste = [str(s) for s in liste]
            self.modelDrop.setStringList(liste)
            self.mdl.setVariable(self.label_select, liste)

            row = self.treeViewProfile.currentIndex().row()
            liste = self.mdl.getVariable(self.label_select)
            self.modelProfile.replaceItem(row, self.label_select, " ; ".join(liste))


    @pyqtSignature("")
    def slotDeleteVarProfile(self):
        """
        Supress a var from profile
        """
        self.modelDrop.removeRows(self.DropList.currentIndex().row(), 1)
        liste = self.modelDrop.stringList()
        liste = [str(s) for s in liste]
        self.mdl.setVariable(self.label_select, liste)

        row = self.treeViewProfile.currentIndex().row()
        liste = self.mdl.getVariable(self.label_select)
        self.modelProfile.replaceItem(row, self.label_select, " ; ".join(liste))


    def __eraseEntries(self):
        """
        Delete all caracters in the entries.
        """
        self.groupBoxProfile.hide()
        self.label_select = None
        self.treeViewProfile.clearSelection()


    @pyqtSignature("")
    def slotFormula(self):
        """
        """
        exp = self.mdl.getFormula(self.label_select)
        exa = """#example: a line segment
#(s, the parameter is always between 0 and 1)
x = 2*s + 3.2;
y = 2;
z = -0.5*s+5;"""
        req = [('x', "x formula"),
               ('y', "y formula"),
               ('z', "z formula")]
        sym = [('s', 'parameter')]

        dialog = QMeiEditorView(self,
                                check_syntax = self.case['package'].get_check_syntax(),
                                expression = exp,
                                required   = req,
                                symbols    = sym,
                                examples   = exa)
        if dialog.exec_():
            result = dialog.get_result()
            log.debug("slotLineFormula -> %s" % str(result))
            setGreenColor(self.pushButtonFormula, False)
            self.mdl.setFormula(self.label_select, result)


    @pyqtSignature("const QString&")
    def slotBaseName(self, text):
        """
        """
        lst = self.mdl.getProfilesLabelsList()
        if text not in lst:
            if self.sender().validator().state == QValidator.Acceptable:
                self.mdl.setLabel(self.label_select, str(text))
                self.label_select = str(text)

                row = self.treeViewProfile.currentIndex().row()
                liste = self.mdl.getVariable(self.label_select)
                self.modelProfile.replaceItem(row, self.label_select, " ; ".join(liste))


    @pyqtSignature("const QString&")
    def slotTitle(self, text):
        """
        """
        if self.sender().validator().state == QValidator.Acceptable:
            self.mdl.setTitle(self.label_select, str(text))


    @pyqtSignature("const QString&")
    def slotFrequence(self, text):
        """
        """
        if self.sender().validator().state == QValidator.Acceptable:
            self.mdl.setOutputFrequency(self.label_select, int(text))


    @pyqtSignature("const QString&")
    def slotFrequenceTime(self, text):
        """
        """
        if self.sender().validator().state == QValidator.Acceptable:
            self.mdl.setOutputFrequency(self.label_select, float(text))


    @pyqtSignature("const QString&")
    def slotNbPoint(self, text):
        """
        """
        if self.sender().validator().state == QValidator.Acceptable:
            self.mdl.setNbPoint(self.label_select, int(text))


    def tr(self, text):
        """
        Translation
        """
        return text


#-------------------------------------------------------------------------------
# Testing part
#-------------------------------------------------------------------------------


if __name__ == "__main__":
    pass


#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
