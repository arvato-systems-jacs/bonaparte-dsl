/*
* generated by Xtext
*/
package de.jpaw.bonaparte.noSQL.dsl;

import de.jpaw.bonaparte.noSQL.dsl.BDslStandaloneSetupGenerated;

/**
 * Initialization support for running Xtext languages 
 * without equinox extension registry
 */
public class BDslStandaloneSetup extends BDslStandaloneSetupGenerated{

    public static void doSetup() {
        new BDslStandaloneSetup().createInjectorAndDoEMFRegistration();
    }
}

