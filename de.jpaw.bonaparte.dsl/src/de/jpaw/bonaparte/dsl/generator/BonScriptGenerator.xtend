 /*
  * Copyright 2012 Michael Bischoff
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  *
  *   http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.
  */
  
package de.jpaw.bonaparte.dsl.generator

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IGenerator
import org.eclipse.xtext.generator.IFileSystemAccess

import org.apache.log4j.Logger
import de.jpaw.bonaparte.dsl.generator.debug.DebugBonScriptGeneratorMain
import de.jpaw.bonaparte.dsl.generator.java.JavaBonScriptGeneratorMainimport java.util.concurrent.atomic.AtomicInteger
import javax.inject.Inject
import de.jpaw.bonaparte.dsl.BonScriptPreferences

class BonScriptGenerator implements IGenerator {
    private static final Logger logger = Logger.getLogger(BonScriptGenerator)
    private static final AtomicInteger globalId = new AtomicInteger(0)
    private final int localId = globalId.incrementAndGet
    
    @Inject DebugBonScriptGeneratorMain generatorDebug
    @Inject JavaBonScriptGeneratorMain generatorJava
    
    def private String filterInfo() {
        "@" + localId + ": "   
    }
    
    public new() {
        logger.info("BonScriptGenerator constructed. " + filterInfo)
    }
        
    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        
            if (BonScriptPreferences.currentPrefs.doDebugOut) {
                logger.info(filterInfo + "start code output: Debug dump for " + resource.URI.toString);
                generatorDebug.doGenerate(resource, fsa)
            }
        
            logger.info(filterInfo + "start code output: Java output for " + resource.URI.toString);
            generatorJava.doGenerate(resource, fsa)
        
            logger.info(filterInfo + "start cleanup");
            DataTypeExtension::clear()
    }
}
