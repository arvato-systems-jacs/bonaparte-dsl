/*
 * generated by Xtext
 */
package de.jpaw.bonaparte.dts.dsl.generator

import de.jpaw.bonaparte.dsl.generator.BonScriptGenerator
import de.jpaw.bonaparte.dts.dsl.generator.ts.TsGeneratorMain
import java.util.concurrent.atomic.AtomicInteger
import javax.inject.Inject
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

/**
 * Generates code from your model files on save.
 *
 * see http://www.eclipse.org/Xtext/documentation.html#TutorialCodeGeneration
 */
class BDtsGenerator implements IGenerator {
    private static Logger LOGGER = Logger.getLogger(BDtsGenerator)
    private static final AtomicInteger globalId = new AtomicInteger(0)
    private final int localId = globalId.incrementAndGet

    @Inject BonScriptGenerator bonaparteGenerator
    @Inject TsGeneratorMain generatorJava

    def private String filterInfo() {
        "#" + localId + ": "
    }

    public new() {
        LOGGER.info("BDtsGenerator constructed. " + filterInfo)
    }

    override void doGenerate(Resource resource, IFileSystemAccess fsa) {

        bonaparteGenerator.doGenerate(resource, fsa)

        LOGGER.info(filterInfo + "start code output: Java output for " + resource.URI.toString);
        generatorJava.doGenerate(resource, fsa)

        LOGGER.info(filterInfo + "start cleanup");
    }
}
