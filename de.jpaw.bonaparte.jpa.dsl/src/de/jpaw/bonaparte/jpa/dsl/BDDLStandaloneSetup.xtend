/*
 * generated by Xtext 2.13.0
 */
package de.jpaw.bonaparte.jpa.dsl


/**
 * Initialization support for running Xtext languages without Equinox extension registry.
 */
class BDDLStandaloneSetup extends BDDLStandaloneSetupGenerated {

	def static void doSetup() {
		new BDDLStandaloneSetup().createInjectorAndDoEMFRegistration()
	}
}
