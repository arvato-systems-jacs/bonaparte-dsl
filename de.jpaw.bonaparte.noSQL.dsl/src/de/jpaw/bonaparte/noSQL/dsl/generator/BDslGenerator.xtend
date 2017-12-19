/*
 * generated by Xtext
 */
package de.jpaw.bonaparte.noSQL.dsl.generator

import de.jpaw.bonaparte.dsl.generator.BonScriptGenerator
import de.jpaw.bonaparte.noSQL.dsl.generator.java.JavaGeneratorMain
import java.util.concurrent.atomic.AtomicInteger
import javax.inject.Inject
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGenerator2
import org.eclipse.xtext.generator.IGeneratorContext

/**
 * Generates code from your model files on save.
 *
 * see http://www.eclipse.org/Xtext/documentation.html#TutorialCodeGeneration
 */
class BDslGenerator implements IGenerator2 {
    private static Logger LOGGER = Logger.getLogger(BDslGenerator)
    private static final AtomicInteger globalId = new AtomicInteger(0)
    private final int localId = globalId.incrementAndGet

    @Inject BonScriptGenerator bonaparteGenerator
    @Inject JavaGeneratorMain generatorJava

    def private String filterInfo() {
        "#" + localId + ": "
    }

    public new() {
        LOGGER.info("BDslGenerator constructed. " + filterInfo)
    }

    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext unused) {

        bonaparteGenerator.doGenerate(resource, fsa, unused)

        LOGGER.info(filterInfo + "start code output: Java output for " + resource.URI.toString);
        generatorJava.doGenerate(resource, fsa)

        LOGGER.info(filterInfo + "start cleanup");
    }

	override afterGenerate(Resource input, IFileSystemAccess2 fsa, IGeneratorContext context) {
	}
	
	override beforeGenerate(Resource input, IFileSystemAccess2 fsa, IGeneratorContext context) {
	}
}
