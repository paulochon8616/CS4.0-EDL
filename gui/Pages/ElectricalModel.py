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
This module defines the electrical thermal flow modelling management.

This module contains the following classes and function:
- ElectricalModel
- ElectricalTestCase
"""

#-------------------------------------------------------------------------------
# Library modules import
#-------------------------------------------------------------------------------

import os, sys, unittest

#-------------------------------------------------------------------------------
# Application modules import
#-------------------------------------------------------------------------------

from code_saturne.Base.Common import *
import code_saturne.Base.Toolbox as Tool
from code_saturne.Base.XMLvariables import Variables, Model
from code_saturne.Pages.ThermalRadiationModel import ThermalRadiationModel
from code_saturne.Pages.ThermalScalarModel import ThermalScalarModel
from code_saturne.Pages.FluidCharacteristicsModel import FluidCharacteristicsModel

#-------------------------------------------------------------------------------
# Coal combustion model class
#-------------------------------------------------------------------------------

class ElectricalModel(Variables, Model):
    """
    """
    def __init__(self, case):
        """
        Constructor.
        """
        self.case = case

        nModels         = self.case.xmlGetNode('thermophysical_models')
        self.node_gas   = nModels.xmlInitNode('gas_combustion',    'model')
        self.node_joule = nModels.xmlInitNode('joule_effect',      'model')
        self.node_atmo  = nModels.xmlInitNode('atmospheric_flows', 'model')
        self.node_coal  = nModels.xmlInitNode('solid_fuels',       'model')
        self.node_bc    = self.case.xmlGetNode('boundary_conditions')

        self.electricalModel = ('off', 'joule', 'arc')
        self.jouleModel = ('off', 'AC/DC', 'three-phase', 'AC/DC+Transformer', 'three-phase+Transformer')
        self.radiativeModel = ('off', 'Coef_Abso', 'TS_radia')


    def defaultElectricalValues(self):
        """
        Return in a dictionnary which contains default values.
        """
        default = {}
        default['model']        = "off"
        default['jouleModel']   = "AC/DC"
        default['gasNumber']    = 0
        default['radiative']    = "off"
        default['scaling']      = "off"
        default['current']      = 0.
        default['power']        = 0.
        default['srrom']        = 0.
        default['scalingModel'] = "general_case"
        default['direction']    = "Z"
        default['location']     = 0
        default['epsilon']      = 0.0002

        return default


    def getAllElectricalModels(self):
        """
        Return all defined electrical models in a tuple.
        """
        return self.electricalModel


    def getAllJoulesModels(self):
        """
        Return all defined joules models in a tuple.
        """
        return self.jouleModel


    @Variables.undoGlobal
    def setElectricalModel(self, model):
        """
        Update the electrical model markup from the XML document.
        """
        self.isInList(model, self.electricalModel)

        if model == 'off':
            self.node_joule['model']   = 'off'
            ThermalRadiationModel(self.case).setRadiativeModel('off')
            ThermalScalarModel(self.case).setThermalModel('off')

        else:
            self.node_gas['model']   = 'off'
            self.node_coal['model']  = 'off'
            self.node_joule['model'] = model
            self.node_atmo['model']  = 'off'
            ThermalScalarModel(self.case).setThermalModel('enthalpy')

        self.__updateScalarAndProperty()
#
#        from code_saturne.Pages.Boundary import Boundary
#        for nodbc in self.node_bc.xmlGetChildNodeList('inlet'):
#            model = Boundary('electric_inlet', nodbc['label'], self.case)
#            model.getTurbulenceChoice()
#
#        del Boundary


    @Variables.noUndo
    def getElectricalModel(self):
        """
        Return the current electrical model.
        """
        model = self.node_joule['model']
        if model not in self.electricalModel:
            model = self.defaultElectricalValues()['model']
            self.setElectricalModel(model)

        return model


    def __updateScalarAndProperty(self):
        """
        Update scalars and properties depending on model
        """
        model = self.getElectricalModel()

        if model == 'off':
            self.__removeVariablesAndProperties([], [])
        else:
            listV = ['elec_pot_r']
            gasN = self.getGasNumber()
            if gasN > 1:
                for gas in range(0, gasN - 1):
                    name = '%s%2.2i' % ('esl_fraction_', gas + 1)
                    listV.append(name)

            listP = ['temperature', 'joule_power', 'elec_sigma']
            for dim in range(0, 3):
                name = '%s%i' % ('current_re_', dim+1)
                listP.append(name)

            if model == 'arc':
                listV.append('vec_potential_01')
                listV.append('vec_potential_02')
                listV.append('vec_potential_03')
                listP.append('laplace_force_')
                if self.getRadiativeModel() == 'Coef_Abso':
                    listP.append('absorption_coeff')
                elif self.getRadiativeModel() == 'TS_radia':
                    listP.append('radiation_source')

            else: # 'joule'
                model = self.getJouleModel()
                if model == 'PotComplexe' or model == 'PotComplexe+CDLTransfo':
                    listV.append('elec_pot_i')
                if model == 'PotComplexe+CDLTransfo':
                    listP.append('current_im_')

            for v in listV:
                self.setNewVariable(self.node_joule, v, tpe="model", label=v)
            for v in listP:
                self.setNewProperty(self.node_joule, v)
            self.__removeVariablesAndProperties(listV, listP)


    def __removeVariablesAndProperties(self, varList, propList):
        """
        Delete variables and properties that are useless accordingly to the model.
        """
        __allVariables = []
        __allProperties = []
        for node in self.node_joule.xmlGetChildNodeList('variable'):
            __allVariables.append(node['name'])
        for node in self.node_joule.xmlGetChildNodeList('property'):
            __allProperties.append(node['name'])

        for v in __allVariables:
            if v not in varList:
                self.node_joule.xmlRemoveChild('variable', name=v)
        for v in __allProperties:
            if v not in propList:
                self.node_joule.xmlRemoveChild('property', name=v)


    @Variables.noUndo
    def getSpeciesLabelsList(self):
        """
        Return the species label list.
        """
        lst = []
        gasN = self.getGasNumber()
        if gasN > 1:
            for gas in range(0, gasN - 1):
                name = '%s%2.2i' % ('YM_ESL', gas + 1)
                node = self.node_joule.xmlGetNode('variable', name=name)
                lst.append(node['label'])
        return lst


    @Variables.noUndo
    def getRadiativeModel(self):
        """
        Return the radiative model for electric model
        """
        node = self.node_joule.xmlInitChildNode('radiative_model', 'model')

        model = node['model']
        if model not in self.radiativeModel:
            model = self.defaultElectricalValues()['radiative']
            self.setRadiativeModel(model)
        return model


    @Variables.undoLocal
    def setRadiativeModel(self, model):
        """
        Input radiative model for electric model
        """
        self.isInList(model, self.radiativeModel)

        node = self.node_joule.xmlInitChildNode('radiative_model', 'model')
        node['model'] = model


    @Variables.noUndo
    def getJouleModel(self):
        """
        Return the joule model
        """
        node = self.node_joule.xmlInitChildNode('joule_model', 'model')

        model = node['model']
        if model not in self.jouleModel:
            model = self.defaultElectricalValues()['jouleModel']
            self.setJouleModel(model)
        return model


    @Variables.undoLocal
    def setJouleModel(self, model):
        """
        Input joule model
        """
        self.isInList(model, self.jouleModel)

        node = self.node_joule.xmlInitChildNode('joule_model', 'model')
        node['model'] = model


    @Variables.noUndo
    def getGasNumber(self):
        """
        Return the number of gas for electric model (read in file)
        """
        nb = self.node_joule.xmlGetInt('gasNumber')
        if nb == None:
            nb = self.defaultElectricalValues()['gasNumber']
            self.setGasNumber(nb)
        return nb


    @Variables.undoLocal
    def setGasNumber(self, val):
        """
        Input the number of gas for electric model
        """
        self.isInt(val)
        self.node_joule.xmlSetData('gasNumber', val)


    @Variables.noUndo
    def getSRROM(self):
        """
        Return the relaxation coefficient for mass density
        """
        value = self.node_joule.xmlGetDouble('density_relaxation')
        if value == None:
            value = self.defaultElectricalValues()['srrom']
            self.setSRROM(value)
        return value


    @Variables.undoLocal
    def setSRROM(self, val):
        """
        Input the relaxation coefficient for mass density
        """
        self.isFloat(val)
        self.node_joule.xmlSetData('density_relaxation', val)


    @Variables.noUndo
    def getPower(self):
        """
        Return the imposed power in watt
        """
        value = self.node_joule.xmlGetDouble('imposed_power')
        if value == None:
            value = self.defaultElectricalValues()['power']
            self.setPower(value)
        return value


    @Variables.undoLocal
    def setPower(self, val):
        """
        Input the imposed power in watt
        """
        self.isFloat(val)
        self.node_joule.xmlSetData('imposed_power', val)


    @Variables.noUndo
    def getCurrent(self):
        """
        Return the imposed current intensity
        """
        value = self.node_joule.xmlGetDouble('imposed_current')
        if value == None:
            value = self.defaultElectricalValues()['power']
            self.setCurrent(value)
        return value


    @Variables.undoLocal
    def setCurrent(self, val):
        """
        Input the imposed current intensity
        """
        self.isFloat(val)
        self.node_joule.xmlSetData('imposed_current', val)


    @Variables.noUndo
    def getScaling(self):
        """
        Get status of "Electric variables" scaling
        """
        node = self.node_joule.xmlInitChildNode('variable_scaling', 'status')
        s = node['status']
        if not s:
            s = self.defaultElectricalValues()['scaling']
            self.setScaling(s)
        return s


    @Variables.undoLocal
    def setScaling(self, status):
        """
        Put status of "Electric variables" scaling
        """
        self.isOnOff(status)
        node = self.node_joule.xmlInitChildNode('variable_scaling', 'status')
        node['status'] = status


    @Variables.noUndo
    def getPropertiesDataFileName(self):
        """
        Get name for properties data (return None if not defined)i
        """
        f = self.node_gas.xmlGetString('data_file')
        return f


    @Variables.undoGlobal
    def setPropertiesDataFileName(self, name):
        """
        Put name for properties data and load file for number gaz and radiative model
        """
        self.node_gas.xmlSetData('data_file', name)
        self.load(name)


    @Variables.noUndo
    def getScalingModel(self):
        """
        Get modele for "Electric variables" scaling
        """
        node = self.node_joule.xmlInitChildNode('recal_model', 'model')
        s = node['model']
        if not s:
            s = self.defaultElectricalValues()['scalingModel']
            self.setScalingModel(s)
        return s


    @Variables.undoLocal
    def setScalingModel(self, model):
        """
        Put modele for "Electric variables" scaling
        """
        self.isInList(model, ('general_case', 'plane_define', 'user'))
        node = self.node_joule.xmlInitChildNode('recal_model', 'model')
        node['model'] = model
        if model != "plane_define":
            node.xmlRemoveChild('direction')
            node.xmlRemoveChild('plane_definition')


    @Variables.noUndo
    def getDirection(self):
        """
        Get direction of current intensity for "Electric variables" scaling
        """
        node = self.node_joule.xmlGetNode('recal_model')
        s = node.xmlGetString('direction')
        if not s:
            s = self.defaultElectricalValues()['direction']
            self.setDirection(s)
        return s


    @Variables.undoLocal
    def setDirection(self, direction):
        """
        Put direction of current intensity for "Electric variables" scaling
        """
        self.isInList(direction, ('X', 'Y', 'Z'))
        node = self.node_joule.xmlGetNode('recal_model')
        node.xmlSetData('direction', direction)


    @Variables.noUndo
    def getPlaneDefinition(self, coord):
        """
        Get plane of current intensity for "Electric variables" scaling
        """
        self.isInList(coord, ('A', 'B', 'C', 'D', 'epsilon'))
        node = self.node_joule.xmlGetNode('recal_model')
        n = node.xmlInitNode('plane_definition')
        value = n.xmlGetDouble(coord)
        if value == None:
            if coord == "epsilon":
                value = self.defaultElectricalValues()['epsilon']
            else:
                value = self.defaultElectricalValues()['location']
            self.setPlaneDefinition(coord, value)
        return value


    @Variables.undoLocal
    def setPlaneDefinition(self, coord, val):
        """
        Put plane current intensity for "Electric variables" scaling
        """
        self.isInList(coord, ('A', 'B', 'C', 'D', 'epsilon'))
        self.isFloat(val)
        node = self.node_joule.xmlGetNode('recal_model')
        n = node.xmlInitNode('plane_definition')
        n.xmlSetData(coord, val)


    @Variables.noUndo
    def getScalarLabel(self, tag):
        """
        Get label for thermal scalar
        """
        label = ""
        node = self.node_joule.xmlGetNode('variable', type='model', name=tag)
        if node:
            label = node['label']

        return label


    def load(self, name):
        """
        read thermophysical file
        """
        #FIXME bug to obtain case_path
        filePath = self.case['data_path']+"/" + name
        try :
            PropFile = open(filePath, "r")
        except :
            return 0

        # Comments
        line = PropFile.readline()
        line = PropFile.readline()
        line = PropFile.readline()
        line = PropFile.readline()
        line = PropFile.readline()
        line = PropFile.readline()
        line = PropFile.readline()
        # NGAZG NPO
        line = PropFile.readline()
        content = line.split()
        self.setGasNumber(int(content[0]))
        line = PropFile.readline()
        line = PropFile.readline()
        line = PropFile.readline()
        line = PropFile.readline()
        line = PropFile.readline()
        # IXKABE
        line = PropFile.readline()
        content = line.split()

        if content[0] == '0':
            model = 'off'
        elif content[0] == '2':
            model = 'Coef_Abso'
        elif content[0] == '1':
            model = 'TS_radia'
        self.setRadiativeModel(model)
        self.__updateScalarAndProperty()


#-------------------------------------------------------------------------------
# Electrical model test case
#-------------------------------------------------------------------------------


class ElectricalTestCase(unittest.TestCase):
    """
    """
    def setUp(self):
        """This method is executed before all "check" methods."""
        from code_saturne.Base.XMLengine import Case, XMLDocument
        from code_saturne.Base.XMLinitialize import XMLinit
        Tool.GuiParam.lang = 'en'
        self.case = Case(None)
        XMLinit(self.case).initialize()
        self.doc = XMLDocument()

    def tearDown(self):
        """This method is executed after all "check" methods."""
        del self.case
        del self.doc

    def xmlNodeFromString(self, string):
        """Private method to return a xml node from string"""
        return self.doc.parseString(string).root()

    def checkElectricalInstantiation(self):
        """
        Check whether the ElectricalModel class could be instantiated
        """
        model = None
        model = ElectricalModel(self.case)
        assert model != None, 'Could not instantiate ElectricalModel'


def suite():
    testSuite = unittest.makeSuite(ElectricalTestCase, "check")
    return testSuite


def runTest():
    print("ElectricalTestCase - TODO**************")
    runner = unittest.TextTestRunner()
    runner.run(suite())


#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
