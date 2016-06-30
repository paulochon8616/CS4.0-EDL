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
This module defines the 'Additional user's scalars' page.

This module contains the following classes:
- NameDelegate
- GGDHDelegate
- VarianceNameDelegate
- VarianceDelegate
- StandardItemModelScalars
- DefineUserScalarsView
"""

#-------------------------------------------------------------------------------
# Standard modules
#-------------------------------------------------------------------------------

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
from code_saturne.Base.QtPage import ComboModel, DoubleValidator, RegExpValidator
from code_saturne.Base.QtPage import to_qvariant, from_qvariant, to_text_string

from code_saturne.Pages.DefineUserScalarsForm import Ui_DefineUserScalarsForm
from code_saturne.Pages.LocalizationModel import LocalizationModel
from code_saturne.Pages.DefineUserScalarsModel import DefineUserScalarsModel
from code_saturne.Pages.TurbulenceModel import TurbulenceModel

#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger("DefineUserScalarsView")
log.setLevel(GuiParam.DEBUG)

#-------------------------------------------------------------------------------
# Line edit delegate for the name
#-------------------------------------------------------------------------------

class NameDelegate(QItemDelegate):
    """
    Use of a QLineEdit in the table.
    """
    def __init__(self, parent=None):
        QItemDelegate.__init__(self, parent)
        self.parent = parent
        self.old_pname = ""


    def createEditor(self, parent, option, index):
        editor = QLineEdit(parent)
        self.old_pname = ""
        #editor.installEventFilter(self)
        rx = "[_a-zA-Z][_A-Za-z0-9]{1," + str(LABEL_LENGTH_MAX-1) + "}"
        self.regExp = QRegExp(rx)
        v = RegExpValidator(editor, self.regExp)
        editor.setValidator(v)
        return editor


    def setEditorData(self, editor, index):
        value = from_qvariant(index.model().data(index, Qt.DisplayRole), to_text_string)
        self.old_pname = str(value)
        editor.setText(value)


    def setModelData(self, editor, model, index):
        if not editor.isModified():
            return

        if editor.validator().state == QValidator.Acceptable:
            new_pname = str(editor.text())

            if new_pname in model.mdl.getScalarNameList():
                default = {}
                default['name']  = self.old_pname
                default['list']   = model.mdl.getScalarNameList()
                default['regexp'] = self.regExp
                log.debug("setModelData -> default = %s" % default)

                from code_saturne.Pages.VerifyExistenceLabelDialogView import VerifyExistenceLabelDialogView
                dialog = VerifyExistenceLabelDialogView(self.parent, default)
                if dialog.exec_():
                    result = dialog.get_result()
                    new_pname = result['name']
                    log.debug("setModelData -> result = %s" % result)
                else:
                    new_pname = self.old_pname

            model.setData(index, to_qvariant(str(new_pname)), Qt.DisplayRole)


#-------------------------------------------------------------------------------
# Combo box delegate for the modelized turbulent fluxes
#-------------------------------------------------------------------------------

class GGDHDelegate(QItemDelegate):
    """
    Use of a combo box in the table.
    """
    def __init__(self, parent, case):
        super(GGDHDelegate, self).__init__(parent)
        self.parent   = parent
        self.case     = case


    def createEditor(self, parent, option, index):
        editor = QComboBox(parent)
        self.modelCombo = ComboModel(editor, 1, 1)
        editor.installEventFilter(self)
        return editor


    def setEditorData(self, editor, index):

        self.modelCombo.addItem(self.tr("SGDH"), "SGDH")
        if TurbulenceModel(self.case).getTurbulenceModel() == "Rij-epsilon" or \
           TurbulenceModel(self.case).getTurbulenceModel() == "Rij-SSG" or \
           TurbulenceModel(self.case).getTurbulenceModel() == "Rij-EBRSM":
            self.modelCombo.addItem(self.tr("GGDH"), "GGDH")
            self.modelCombo.addItem(self.tr("AFM"), "AFM")
            self.modelCombo.addItem(self.tr("DFM"), "DFM")


    def setModelData(self, comboBox, model, index):
        txt = str(comboBox.currentText())
        value = self.modelCombo.dicoV2M[txt]
        model.setData(index, to_qvariant(value), Qt.DisplayRole)


    def tr(self, text):
        """
        Translation
        """
        return text

#-------------------------------------------------------------------------------
# Line edit delegate for the variance name
#-------------------------------------------------------------------------------

class VarianceNameDelegate(QItemDelegate):
    """
    Use of a QLineEdit in the table.
    """
    def __init__(self, parent=None):
        QItemDelegate.__init__(self, parent)
        self.parent = parent
        self.old_pname = ""


    def createEditor(self, parent, option, index):
        editor = QLineEdit(parent)
        self.old_pname = ""
        rx = "[_a-zA-Z][_A-Za-z0-9]{1," + str(LABEL_LENGTH_MAX-1) + "}"
        self.regExp = QRegExp(rx)
        v = RegExpValidator(editor, self.regExp)
        editor.setValidator(v)
        return editor


    def setEditorData(self, editor, index):
        value = from_qvariant(index.model().data(index, Qt.DisplayRole), to_text_string)
        self.old_pname = str(value)
        editor.setText(value)


    def setModelData(self, editor, model, index):
        if not editor.isModified():
            return

        if editor.validator().state == QValidator.Acceptable:
            new_pname = str(editor.text())

            if new_pname in model.mdl.getScalarNameList():
                default = {}
                default['name']  = self.old_pname
                default['list']   = model.mdl.getScalarNameList()
                default['regexp'] = self.regExp
                log.debug("setModelData -> default = %s" % default)

                from code_saturne.Pages.VerifyExistenceLabelDialogView import VerifyExistenceLabelDialogView
                dialog = VerifyExistenceLabelDialogView(self.parent, default)
                if dialog.exec_():
                    result = dialog.get_result()
                    new_pname = result['name']
                    log.debug("setModelData -> result = %s" % result)
                else:
                    new_pname = self.old_pname

            model.setData(index, to_qvariant(str(new_pname)), Qt.DisplayRole)


#-------------------------------------------------------------------------------
# Combo box delegate for the variance
#-------------------------------------------------------------------------------

class VarianceDelegate(QItemDelegate):
    """
    Use of a combo box in the table.
    """
    def __init__(self, parent):
        super(VarianceDelegate, self).__init__(parent)
        self.parent   = parent


    def createEditor(self, parent, option, index):
        editor = QComboBox(parent)
        self.modelCombo = ComboModel(editor, 1, 1)
        editor.installEventFilter(self)
        return editor


    def setEditorData(self, editor, index):
        l1 = index.model().mdl.getScalarNameList()
        for label in index.model().mdl.getThermalScalarName():
            l1.append(label)
        for s in index.model().mdl.getScalarsVarianceList():
            if s in l1: l1.remove(s)

        for s in l1:
            self.modelCombo.addItem(s, s)


    def setModelData(self, comboBox, model, index):
        txt = str(comboBox.currentText())
        value = self.modelCombo.dicoV2M[txt]
        model.setData(index, to_qvariant(value), Qt.DisplayRole)


    def tr(self, text):
        """
        Translation
        """
        return text

#-------------------------------------------------------------------------------
# StandarItemModel class
#-------------------------------------------------------------------------------

class StandardItemModelScalars(QStandardItemModel):
    """
    """
    def __init__(self, parent, mdl):
        """
        """
        QStandardItemModel.__init__(self)

        self.headers = [self.tr("Name"), self.tr("Turbulent flux model")]

        self.setColumnCount(len(self.headers))

        self.toolTipRole = [self.tr("Code_Saturne keyword: NSCAUS"),
                            self.tr("Code_Saturne keyword: ITURT")]

        self._data = []
        self.parent = parent
        self.mdl  = mdl


    def data(self, index, role):
        if not index.isValid():
            return to_qvariant()

        row = index.row()
        col = index.column()

        if role == Qt.ToolTipRole:
            return to_qvariant(self.toolTipRole[col])
        if role == Qt.DisplayRole:
            return to_qvariant(self._data[row][col])

        return to_qvariant()


    def flags(self, index):
        # first variable if thermal scalar
        if self.mdl.getThermalScalarName():
            if index.row() == 0 and index.column() == 0 :
                return Qt.ItemIsEnabled | Qt.ItemIsSelectable
        if not index.isValid():
            return Qt.ItemIsEnabled
        return Qt.ItemIsEnabled | Qt.ItemIsSelectable | Qt.ItemIsEditable


    def headerData(self, section, orientation, role):
        if orientation == Qt.Horizontal and role == Qt.DisplayRole:
            return to_qvariant(self.headers[section])
        return to_qvariant()


    def setData(self, index, value, role):
        if not index.isValid():
            return Qt.ItemIsEnabled

        # Update the row in the table
        row = index.row()
        col = index.column()

        # Label
        if col == 0:
            old_pname = self._data[row][col]
            new_pname = str(from_qvariant(value, to_text_string))
            self._data[row][col] = new_pname
            self.mdl.renameScalarLabel(old_pname, new_pname)

        # GGDH
        elif col == 1:
            turbFlux = str(from_qvariant(value, to_text_string))
            self._data[row][col] = turbFlux
            [name, var] = self._data[row]
            self.mdl.setTurbulentFluxModel(name, turbFlux)

        self.emit(SIGNAL("dataChanged(const QModelIndex &, const QModelIndex &)"), index, index)
        return True


    def getData(self, index):
        row = index.row()
        return self._data[row]


    def newItem(self, existing_name=None):
        """
        Add an item in the table view
        """
        row = self.rowCount()

        name = self.mdl.addUserScalar(existing_name)
        turbFlux = self.mdl.getTurbulentFluxModel(name)
        scalar = [name, turbFlux]

        self.setRowCount(row+1)
        self._data.append(scalar)


    def getItem(self, row):
        """
        Return the values for an item.
        """
        [name, turbFlux] = self._data[row]
        return name, turbFlux


    def deleteItem(self, row):
        """
        Delete the row in the model.
        """
        log.debug("deleteItem row = %i " % row)

        del self._data[row]
        row = self.rowCount()
        self.setRowCount(row-1)


#-------------------------------------------------------------------------------
# StandarItemModel class
#-------------------------------------------------------------------------------

class StandardItemModelVariance(QStandardItemModel):
    """
    """
    def __init__(self, parent, mdl):
        """
        """
        QStandardItemModel.__init__(self)

        self.headers = [self.tr("Variance"),
                        self.tr("Species_Name")]

        self.setColumnCount(len(self.headers))

        self.toolTipRole = [self.tr("Code_Saturne keyword: ???"),
                            self.tr("Code_Saturne keyword: ???")]

        self._data = []
        self.parent = parent
        self.mdl  = mdl


    def data(self, index, role):
        if not index.isValid():
            return to_qvariant()

        row = index.row()
        col = index.column()

        if role == Qt.ToolTipRole:
            return to_qvariant(self.toolTipRole[col])
        if role == Qt.DisplayRole:
            return to_qvariant(self._data[row][col])

        return to_qvariant()


    def flags(self, index):
        if not index.isValid():
            return Qt.ItemIsEnabled
        return Qt.ItemIsEnabled | Qt.ItemIsSelectable | Qt.ItemIsEditable


    def headerData(self, section, orientation, role):
        if orientation == Qt.Horizontal and role == Qt.DisplayRole:
            return to_qvariant(self.headers[section])
        return to_qvariant()


    def setData(self, index, value, role):
        if not index.isValid():
            return Qt.ItemIsEnabled

        # Update the row in the table
        row = index.row()
        col = index.column()

        # Label
        if col == 0:
            old_pname = self._data[row][col]
            new_pname = str(from_qvariant(value, to_text_string))
            self._data[row][col] = new_pname
            self.mdl.renameScalarLabel(old_pname, new_pname)


        # Variance
        elif col == 1:
            variance = str(from_qvariant(value, to_text_string))
            self._data[row][col] = variance
            [name, var] = self._data[row]
            self.mdl.setScalarVariance(name,var)

        self.emit(SIGNAL("dataChanged(const QModelIndex &, const QModelIndex &)"), index, index)
        return True


    def getData(self, index):
        row = index.row()
        return self._data[row]


    def newItem(self, existing_name=None):
        """
        Add an item in the table view
        """
        if not self.mdl.getScalarNameList() and not self.mdl.getThermalScalarName():
            title = self.tr("Warning")
            msg   = self.tr("There is no user scalar.\n"\
                            "Please define a user scalar.")
            QMessageBox.warning(self.parent, title, msg)
            return
        row = self.rowCount()
        if existing_name == None:
            name = self.mdl.addVariance()
        else:
            name = self.mdl.addVariance(existing_name)
        var = self.mdl.getScalarVariance(name)
        if var in ("", "no variance", "no_variance"):
            var = "no"
        scalar = [name, var]

        self.setRowCount(row+1)
        self._data.append(scalar)


    def getItem(self, row):
        """
        Return the values for an item.
        """
        [name, var] = self._data[row]
        return name, var


    def deleteItem(self, row):
        """
        Delete the row in the model.
        """
        log.debug("deleteItem row = %i " % row)

        del self._data[row]
        row = self.rowCount()
        self.setRowCount(row-1)


#-------------------------------------------------------------------------------
# Main class
#-------------------------------------------------------------------------------

class DefineUserScalarsView(QWidget, Ui_DefineUserScalarsForm):
    """
    """
    def __init__(self, parent, case, stbar):
        """
        Constructor
        """
        QWidget.__init__(self, parent)

        Ui_DefineUserScalarsForm.__init__(self)
        self.setupUi(self)

        self.case = case

        self.case.undoStopGlobal()

        self.mdl = DefineUserScalarsModel(self.case)

        # tableView
        self.modelScalars = StandardItemModelScalars(self, self.mdl)
        self.modelVariance = StandardItemModelVariance(self, self.mdl)
        self.tableScalars.horizontalHeader().setResizeMode(QHeaderView.Stretch)
        self.tableVariance.horizontalHeader().setResizeMode(QHeaderView.Stretch)

        # Delegates
        delegateLabel        = NameDelegate(self.tableScalars)
        delegateGGDH         = GGDHDelegate(self.tableScalars, self.case)
        delegateVarianceName = VarianceNameDelegate(self.tableVariance)
        delegateVariance     = VarianceDelegate(self.tableVariance)

        self.tableScalars.setItemDelegateForColumn(0, delegateLabel)
        self.tableScalars.setItemDelegateForColumn(1, delegateGGDH)
        self.tableVariance.setItemDelegateForColumn(0, delegateVarianceName)
        self.tableVariance.setItemDelegateForColumn(1, delegateVariance)

        # Connections
        self.connect(self.pushButtonNew,       SIGNAL("clicked()"), self.slotAddScalar)
        self.connect(self.pushButtonDelete,    SIGNAL("clicked()"), self.slotDeleteScalar)
        self.connect(self.modelScalars,        SIGNAL("dataChanged(const QModelIndex &, const QModelIndex &)"), self.dataChanged)
        self.connect(self.pushButtonVarNew,    SIGNAL("clicked()"), self.slotAddVariance)
        self.connect(self.pushButtonVarDelete, SIGNAL("clicked()"), self.slotDeleteVariance)
        self.connect(self.modelVariance,       SIGNAL("dataChanged(const QModelIndex &, const QModelIndex &)"), self.dataChanged)

        # widget initialization
        self.tableScalars.reset()
        self.modelScalars = StandardItemModelScalars(self, self.mdl)
        self.tableScalars.setModel(self.modelScalars)

        self.tableVariance.reset()
        self.modelVariance = StandardItemModelVariance(self, self.mdl)
        self.tableVariance.setModel(self.modelVariance)

        l1 = self.mdl.getScalarNameList()
        for s in self.mdl.getScalarsVarianceList():
            if s in l1: l1.remove(s)
        for name in self.mdl.getThermalScalarName():
            self.modelScalars.newItem(name)
        for name in l1:
            self.modelScalars.newItem(name)
        for name in self.mdl.getScalarsVarianceList():
            self.modelVariance.newItem(name)

        self.case.undoStartGlobal()


    @pyqtSignature("")
    def slotAddScalar(self):
        """
        Add a new item in the table when the 'Create' button is pushed.
        """
        self.tableScalars.clearSelection()
        self.modelScalars.newItem()


    @pyqtSignature("")
    def slotDeleteScalar(self):
        """
        Just delete the current selected entries from the table and
        of course from the XML file.
        """
        lst = []
        for index in self.tableScalars.selectionModel().selectedRows():
            row = index.row()
            lst.append(row)

        lst.sort()
        lst.reverse()

        for row in lst:
            name = self.modelScalars.getItem(row)[0]
            if self.mdl.getScalarType(name) == 'user':
                self.mdl.deleteScalar(name)
                self.modelScalars.deleteItem(row)
            row_var = self.modelVariance.rowCount()
            del_var = []
            for r in range(row_var):
                if name == self.modelVariance.getItem(r)[1]:
                    del_var.append(self.modelVariance.getItem(r)[0])
            for var in del_var:
                tot_row = self.modelVariance.rowCount()
                del_stat = 0
                for rr in range(tot_row):
                    if del_stat == 0:
                        if var == self.modelVariance.getItem(rr)[0]:
                            del_stat=1
                            self.modelVariance.deleteItem(rr)

        self.tableScalars.clearSelection()


    @pyqtSignature("")
    def slotAddVariance(self):
        """
        Add a new item in the table when the 'Create' button is pushed.
        """
        self.tableVariance.clearSelection()
        self.modelVariance.newItem()


    @pyqtSignature("")
    def slotDeleteVariance(self):
        """
        Just delete the current selected entries from the table and
        of course from the XML file.
        """
        lst = []
        for index in self.tableVariance.selectionModel().selectedRows():
            row = index.row()
            lst.append(row)

        lst.sort()
        lst.reverse()

        for row in lst:
            name = self.modelVariance.getItem(row)[0]
            self.mdl.deleteScalar(name)
            self.modelVariance.deleteItem(row)

        self.tableVariance.clearSelection()


    @pyqtSignature("const QModelIndex &, const QModelIndex &")
    def dataChanged(self, topLeft, bottomRight):
        for row in range(topLeft.row(), bottomRight.row()+1):
            self.tableView.resizeRowToContents(row)
        for col in range(topLeft.column(), bottomRight.column()+1):
            self.tableView.resizeColumnToContents(col)


    def tr(self, text):
        """
        Translation
        """
        return text

#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
