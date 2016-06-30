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
"""

#-------------------------------------------------------------------------------
# Library odules import
#-------------------------------------------------------------------------------

import string, unittest

#-------------------------------------------------------------------------------
# Application modules import
#-------------------------------------------------------------------------------

from code_saturne.Base.Common import *
import code_saturne.Base.Toolbox as Tool
from code_saturne.Base.XMLmodel import XMLmodel, ModelTest
from code_saturne.Base.XMLvariables import Model, Variables
from code_saturne.Pages.DefineUserScalarsModel import DefineUserScalarsModel
from code_saturne.Pages.ThermalRadiationModel import ThermalRadiationModel

#-------------------------------------------------------------------------------
# Model class
#-------------------------------------------------------------------------------

class OutputVolumicVariablesModel(Model):

    def __init__(self, case):
        """
        Constuctor.
        """
        self.case = case
        self.node_models    = self.case.xmlInitNode('thermophysical_models')
        self.analysis_ctrl  = self.case.xmlInitNode('analysis_control')
        self.fluid_prop     = self.case.xmlInitNode('physical_properties')
        self.node_model_vp  = self.node_models.xmlInitNode('velocity_pressure')
        self.node_ale       = self.node_models.xmlGetChildNode('ale_method')
        self.node_output    = self.analysis_ctrl.xmlInitNode('output')
        self.node_probe     = self.node_output.xmlGetNodeList('probe','name')
        self.node_means     = self.analysis_ctrl.xmlInitNode('time_averages')

        model = XMLmodel(self.case)

        self.listNodeVolum = (self._getListOfVelocityPressureVariables(),
                              model.getTurbNodeList(),
                              self.getThermalScalar(),
                              self.getAdditionalScalar(),
                              self.getAdditionalScalarProperty(),
                              self.getFluidProperty(),
                              self.getTimeProperty(),
                              self.getMeteoScalProper(),
                              self.getElecScalProper(),
                              self.getPuCoalScalProper(),
                              self.getGasCombScalProper(),
                              self._getWeightMatrixProperty(),
                              self.getListOfTimeAverage(),
                              self._getListOfAleMethod(),
                              self._getThermalRadiativeProperties())

        self.dicoLabelName = {}
        self.list_name = []
        self._updateDicoLabelName()


# Following private methods: (to see for gathering eventually)

    def _defaultValues(self):
        """
        Return in a dictionnary which contains default values
        """
        default = {}
        default['status']    = "on"

        return default


    def _updateDicoLabelName(self):
        """
        Update dictionaries of labels for all variables, properties .....
        """
        for nodeList in self.listNodeVolum:
            for node in nodeList:
                name = node['name']
                if not name: name = node['label']
                if not node['label']:
                    msg = "xml node named "+ name +" has no label"
                    raise ValueError(msg)
                self.dicoLabelName[name] = node['label']
                self.list_name.append(name)


    def _getListOfVelocityPressureVariables(self):
        """
        Private method: return node of properties of weight matrix
        """
        nodeList = []
        for tag in ('variable', 'property'):
            for node in self.node_model_vp.xmlGetNodeList(tag):
                if not node['support']:
                    nodeList.append(node)
        return nodeList


    def _getWeightMatrixProperty(self):
        """
        Private method: return node of properties of weight matrix
        """
        nodeList = []
        node0 = self.case.xmlGetNode('numerical_parameters')
        node1 = node0.xmlGetNode('velocity_pressure_coupling', 'status')
        if node1:
            if node1['status'] == 'on':
                nodeList = node0.xmlGetNodeList('property')
        return nodeList


    def _getListOfAleMethod(self):
        """
        Private method: return list of variables and properties for ale method if it's activated
        """
        nodeList = []
        if self.node_ale['status'] == 'on':
            for tag in ('variable', 'property'):
                for node in self.node_ale.xmlGetChildNodeList(tag):
                    nodeList.append(node)

        return nodeList


    def _getThermalRadiativeProperties(self):
        """
        Private method: return list of volumic properties for thermal radiation
        """
        nodeList = []
        if ThermalRadiationModel(self.case).getRadiativeModel() != "off":
            self.node_ray = self.node_models.xmlGetNode('radiative_transfer')
            for node in self.node_ray.xmlGetChildNodeList('property'):
                if not node['support']:
                    nodeList.append(node)
        return nodeList


# Following methods also called by ProfilesModel and TimeAveragesModel

    @Variables.noUndo
    def getThermalScalar(self):
        """
        Return node of thermal scalar (idem ds NumericalParamEquationModel)
        """
        node_models = self.case.xmlGetNode('thermophysical_models')
        node = node_models.xmlGetNode('thermal_scalar')
        return node.xmlGetNodeList('variable', type='thermal')


    @Variables.noUndo
    def getPuCoalScalProper(self):
        """
        Return list fo nodes of pulverized coal.
        Also called by ProfilesModel and TimeAveragesModel
        """
        nodList = []
        node = self.node_models.xmlGetNode('solid_fuels', 'model')
        model = node['model']
        varList = []
        if model != 'off':
            for var in ('variable', 'property'):
                nodList = node.xmlGetNodeList(var)
                for nodvar in nodList:
                    varList.append(nodvar)
        return varList


    @Variables.noUndo
    def getGasCombScalProper(self):
        """
        Return list fo nodes of gas combustion.
        Also called by ProfilesModel and TimeAveragesModel
        """
        nodList = []
        node = self.node_models.xmlGetNode('gas_combustion', 'model')
        model = node['model']
        varList = []
        if model != 'off':
            for var in ('variable', 'property'):
                nodList = node.xmlGetNodeList(var)
                for nodvar in nodList:
                    varList.append(nodvar)
        return varList


    @Variables.noUndo
    def getMeteoScalProper(self):
        """
        Return list fo nodes of atmospheric flows.
        Also called by ProfilesModel and TimeAveragesModel
        """
        nodList = []
        node = self.node_models.xmlGetNode('atmospheric_flows', 'model')
        if not node: return []
        model = node['model']
        varList = []
        if model != 'off':
            for var in ('variable', 'property'):
                nodList = node.xmlGetNodeList(var)
                for nodvar in nodList:
                    varList.append(nodvar)
        return varList


    @Variables.noUndo
    def getElecScalProper(self):
        """
        Return list fo nodes of electric flows.
        Also called by ProfilesModel and TimeAveragesModel
        """
        nodList = []
        node = self.node_models.xmlGetNode('joule_effect', 'model')
        if not node: return []
        model = node['model']
        varList = []
        if model != 'off':
            for var in ('variable', 'property'):
                nodList = node.xmlGetNodeList(var)
                for nodvar in nodList:
                    varList.append(nodvar)
        return varList


    @Variables.noUndo
    def getAdditionalScalar(self):
        """
        Return list of nodes of user scalars
        Also called by ProfilesModel and TimeAveragesModel
        (idem ds NumericalParamEquationModel named getAdditionalScalarNodes)
        """
        node = self.case.xmlGetNode('additional_scalars')
        return node.xmlGetNodeList('variable', type='user')


    @Variables.noUndo
    def getAdditionalScalarProperty(self):
        """
        Return list of nodes of properties of user scalars
        Also called by ProfilesModel and TimeAveragesModel
        """
        nodeList = []
        for node in self.getAdditionalScalar():
            L = node.xmlGetNode('property', choice='variable')
            if L:
                nodeList.append(L)
        return nodeList


    @Variables.noUndo
    def getFluidProperty(self):
        """
        Return list of nodes of fluid properties
        Also called by ProfilesModel and TimeAveragesModel
        """
        nodeList = []
        model = self.getThermalScalar()

        node = self.fluid_prop.xmlGetNode('fluid_properties')
        if node:
            for prop in ('density',
                         'molecular_viscosity',
                         'specific_heat',
                         'thermal_conductivity'):
                L = node.xmlGetNode('property', name=prop, choice='variable')
                if L:
                    nodeList.append(L)

        return nodeList


    @Variables.noUndo
    def getTimeProperty(self):
        """
        Return list fo nodes of properties of time_parameters.
        Also called by ProfilesModel and TimeAveragesModel
        """
        nodeList = []

        node1 = self.analysis_ctrl.xmlGetNode('time_parameters')

        if node1:
            if node1.xmlGetInt('time_passing'):
                node2 = node1.xmlGetNode('property', name='local_time_step')
                if node2:
                    nodeList.append(node2)

            for prop in ('courant_number', 'fourier_number'):
                L = node1.xmlGetNode('property', name=prop)
                if L: nodeList.append(L)

        return nodeList


    @Variables.noUndo
    def getListOfTimeAverage(self):
        """
        Return list of time averages variables
        Also called by ProfilesModel
        """
        nodeList = []
        for node in self.node_means.xmlGetNodeList('time_average'):
            nodeList.append(node)

        return nodeList


#Following methods only called by the View
    @Variables.noUndo
    def getLabelsList(self):
        """
        Return list of labels for all variables, properties .....Only for the View
        """
        lst = []
        for nodeList in self.listNodeVolum:
            for node in nodeList:
                lst.append(node['label'])
        return lst


    @Variables.noUndo
    def getVariableProbeList(self):
        """ Return list of node for probes """
        probeList = []
        for node in self.node_probe:
            probeList.append(node['name'])
        return probeList


    @Variables.noUndo
    def getProbesList(self, label):
        """
        Return list of probes if it exists for node['name'] = name. Only for the View
        """
        self.isInList(label, self.getLabelsList())
        lst = self.getVariableProbeList()
        for nodeList in self.listNodeVolum:
            for node in nodeList:
                if node['label'] == label:
                    node_probes = node.xmlGetChildNode('probes')
                    if node_probes:
                        nb_probes = node_probes['choice']
                        if nb_probes == '0':
                            lst = []
                        elif nb_probes > '0':
                            lst = []
                            for n in node_probes.xmlGetChildNodeList('probe_recording'):
                                lst.append(n['name'])
        return lst


    @Variables.noUndo
    def getPrintingStatus(self, label):
        """
        Return status of markup printing from node with label. Only for the View
        """
        self.isInList(label, self.getLabelsList())
        status = self._defaultValues()['status']
        for nodeList in self.listNodeVolum:
            for node in nodeList:
                if node['label'] == label:
                    node_printing = node.xmlGetChildNode('listing_printing', 'status')
                    if node_printing:
                        status = node_printing['status']
        return status


    @Variables.noUndo
    def getPostStatus(self, label):
        """
        Return status of markup  post processing from node with label. Only for the View
        """
        self.isInList(label, self.getLabelsList())
        status = self._defaultValues()['status']
        for nodeList in self.listNodeVolum:
            for node in nodeList:
                if node['label'] == label:
                    node_post = node.xmlGetChildNode('postprocessing_recording', 'status')
                    if node_post:
                        status = node_post['status']
        return status


    @Variables.undoLocal
    def setVariableLabel(self, old_label, new_label):
        """
        Replace old_label by new_label for node with name and old_label. Only for the View
        """
        # fusion de cette methode avec DefineUserScalarsModel.renameScalarLabel
        self.isInList(old_label, self.getLabelsList())
        self.isNotInList(new_label, [""])

        if old_label != new_label:
            self.isNotInList(new_label, self.getLabelsList())
        for nodeList in self.listNodeVolum:
            for node in nodeList:
                if node['label'] == old_label:
                    node['label'] = new_label

        self._updateDicoLabelName()
        self._updateBoundariesNodes(old_label, new_label)

        for node in self.case.xmlGetNodeList('formula'):
            f = node.xmlGetTextNode()
            if f:
                f.replace(old_label, new_label)
                node.xmlSetTextNode(f)


    def _updateBoundariesNodes(self, old_label, new_label):
        """
        Update good label for boundaries nodes with name and label. Only for the View
        """
        self.node_bc  = self.case.xmlInitNode('boundary_conditions')
        self.node_var = self.node_bc.xmlInitNodeList('variable')

        for node in self.node_var:
            if node['label'] == old_label:
                node['label'] = new_label


    @Variables.undoLocal
    def setPrintingStatus(self, label, status):
        """
        Put status for balise printing from node with name and label
        """
        self.isOnOff(status)
        self.isInList(label, self.getLabelsList())
        for nodeList in self.listNodeVolum:
            for node in nodeList:
                if node['label'] == label:
                    if status == 'off':
                        node.xmlInitChildNode('listing_printing')['status'] = status
                    else:
                        if node.xmlGetChildNode('listing_printing'):
                            node.xmlRemoveChild('listing_printing')


    @Variables.noUndo
    def getVariableLabel(self, name) :
        """
        return label of name variable
        """
        for variableType in ('variable', 'property') :
            node = self.case.xmlGetNode(variableType, name = name)
            if node != None:
                break

        if node != None:
            label = node['label']
            return label
        else :
            msg = "This variable " + name + " doesn't exist"
            raise ValueError, msg


    @Variables.undoLocal
    def setPostStatus(self, label, status):
        """
        Put status for balise postprocessing from node with name and label
        """
        self.isOnOff(status)
        self.isInList(label, self.getLabelsList())
        for nodeList in self.listNodeVolum:
            for node in nodeList:
                if node['label'] == label:
                    if status == 'off':
                        node.xmlInitChildNode('postprocessing_recording')['status'] = status
                    else:
                        if node.xmlGetChildNode('postprocessing_recording'):
                            node.xmlRemoveChild('postprocessing_recording')


    def updateProbes(self, label, lst):
        """
        Update probe_recording markups if it exists
        """
        self.isInList(label, self.getLabelsList())
        nb = len(lst.split())
        if nb == len(self.getVariableProbeList()):
            for nodeList in self.listNodeVolum:
                for node in nodeList:
                    if node['label'] == label:
                        try:
                            node.xmlRemoveChild('probes')
                        except:
                            pass
        else:
            for nodeList in self.listNodeVolum:
                for node in nodeList:
                    if node['label'] == label:
                        try:
                            node.xmlRemoveChild('probes')
                        except:
                            pass
                        n = node.xmlInitNode('probes', choice=str(nb))
                        if nb > 0:
                            for i in lst.split():
                                n.xmlInitChildNodeList('probe_recording',name=i)

#-------------------------------------------------------------------------------
# OutputVolumicVariablesModel Test Class
#-------------------------------------------------------------------------------

class OutputVolumicVariablesModelTestCase(ModelTest):
    """
    Unittest
    """
    def checkOutputVolumicVariablesModelInstantiation(self):
        """Check whether the OutputVolumicVariablesModel class could be instantiated"""
        mdl = None
        mdl = OutputVolumicVariablesModel(self.case)
        assert mdl != None, 'Could not instantiate OutputVolumicVariablesModel'


    def checkSetVariableLabel(self):
        """
        Check whether the OutputVolumicVariablesModel class could be set a label
        of property
        """
        model = OutputVolumicVariablesModel(self.case)
        model.setVariableLabel('VelocitV', 'vitV')
        node = model.node_models.xmlInitNode('velocity_pressure')
        doc = '''<velocity_pressure>
                    <variable label="Pressure" name="pressure"/>
                    <variable label="VelocitU" name="velocity_U"/>
                    <variable label="vitV" name="velocity_V"/>
                    <variable label="VelocitW" name="velocity_W"/>
                    <property label="total_pressure" name="total_pressure"/>
                    <property label="Yplus" name="yplus" support="boundary"/>
                    <property label="Efforts" name="effort" support="boundary"/>
                 </velocity_pressure>'''
        assert node == self.xmlNodeFromString(doc),\
            'Could not set label of property in output volumic variables model'

    def checkSetAndGetPrintingStatus(self):
        """
        Check whether the OutputVolumicVariablesModel class could be
        set and get status for printing listing
        """
        from code_saturne.Pages.ThermalScalarModel import ThermalScalarModel
        ThermalScalarModel(self.case).setThermalModel('temperature_celsius')
        del ThermalScalarModel

        mdl = OutputVolumicVariablesModel(self.case)
        mdl.setPrintingStatus('TempC', 'off')
        node_out = mdl.case.xmlGetNode('additional_scalars')
        doc = '''<additional_scalars>
                    <variable label="TempC" name="temperature_celsius" type="thermal">
                        <initial_value zone_id="1">20.0</initial_value>
                        <min_value>-1e+12</min_value>
                        <max_value>1e+12</max_value>
                        <listing_printing status="off"/>
                    </variable>
                 </additional_scalars>'''

        assert node_out == self.xmlNodeFromString(doc),\
            'Could not set status of listing printing in output volumic variables model'
        assert mdl.getPrintingStatus('TempC') == 'off',\
            'Could not get status of listing printing in output volumic variables model'

    def checkSetAndGetPostStatus(self):
        """
        Check whether the OutputVolumicVariablesModel class could be
        set and get status for printing
        """
        from code_saturne.Pages.ThermalScalarModel import ThermalScalarModel
        ThermalScalarModel(self.case).setThermalModel('temperature_celsius')
        del ThermalScalarModel

        mdl = OutputVolumicVariablesModel(self.case)
        mdl.setPostStatus('TempC', 'off')
        node_out = mdl.case.xmlGetNode('additional_scalars')
        doc = '''<additional_scalars>
                    <variable label="TempC" name="temperature_celsius" type="thermal">
                        <initial_value zone_id="1">20.0</initial_value>
                        <min_value>-1e+12</min_value>
                        <max_value>1e+12</max_value>
                        <postprocessing_recording status="off"/>
                    </variable>
                 </additional_scalars>'''

        assert node_out == self.xmlNodeFromString(doc),\
            'Could not set status of post processing in output volumic variables model'
        assert mdl.getPostStatus('TempC') == 'off',\
            'Could not get status of post processing in output volumic variables model'

    def checkSetAndGetPostStatusForRadiativeProperties(self):
        """
        Check whether the OutputVolumicVariablesModel class could be
        set and get status for post processing of radaitive property
        """
        from code_saturne.Pages.ThermalRadiationModel import ThermalRadiationModel
        ThermalRadiationModel(self.case).setRadiativeModel('dom')
        del ThermalRadiationModel

        mdl = OutputVolumicVariablesModel(self.case)
        mdl.setPostStatus('Srad', 'off')
        node_out = mdl.case.xmlGetNode('radiative_transfer')

        doc = '''<radiative_transfer model="dom">
                    <property label="Srad" name="srad">
                        <postprocessing_recording status="off"/>
                    </property><property label="Qrad" name="qrad"/>
                    <property label="Absorp" name="absorp"/>
                    <property label="Emiss" name="emiss"/>
                    <property label="CoefAb" name="coefAb"/>
                    <property label="Wall_temp" name="wall_temp" support="boundary"/>
                    <property label="Flux_incident" name="flux_incident" support="boundary"/>
                    <property label="Th_conductivity" name="thermal_conductivity" support="boundary"/>
                    <property label="Thickness" name="thickness" support="boundary"/>
                    <property label="Emissivity" name="emissivity" support="boundary"/>
                    <property label="Flux_net" name="flux_net" support="boundary"/>
                    <property label="Flux_convectif" name="flux_convectif" support="boundary"/>
                    <property label="Coeff_ech_conv" name="coeff_ech_conv" support="boundary"/>
                    <restart status="off"/>
                    <directions_number>32</directions_number>
                    <absorption_coefficient type="constant">0</absorption_coefficient>
                 </radiative_transfer>'''

        assert node_out == self.xmlNodeFromString(doc),\
        'Could not set status of post processing for radiative property \
                   in output volumic variables model'
        assert mdl.getPostStatus('Srad') == 'off',\
        'Could not get status of post processing for radiative property \
                   in output volumic variables model'


def suite():
    testSuite = unittest.makeSuite(OutputVolumicVariablesModelTestCase, "check")
    return testSuite

def runTest():
    print("OutputVolumicVariablesModelTestCase")
    runner = unittest.TextTestRunner()
    runner.run(suite())

#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
