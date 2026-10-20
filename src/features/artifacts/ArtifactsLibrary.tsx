import { useMemo, useState } from 'react'
import { useMutation, useQuery } from '@tanstack/react-query'
import { Search, X } from 'lucide-react'
import { getArtifacts, lumiQueryKeys, submitArtifactQuiz, type LumiApplicationSettings, type LumiArtifact, type LumiQuizResult } from '../../lib/lumi-api'

type Flashcard = { front: string; back: string }
type QuizQuestion = { prompt: string; options: string[] }

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

function isFlashcards(value: unknown): value is { type: 'flashcards'; cards: Flashcard[] } {
  return isRecord(value) && value.type === 'flashcards' && Array.isArray(value.cards) && value.cards.length > 0 && value.cards.every((card) => isRecord(card) && typeof card.front === 'string' && typeof card.back === 'string')
}

function isQuiz(value: unknown): value is { type: 'quiz'; questions: QuizQuestion[] } {
  return isRecord(value) && value.type === 'quiz' && Array.isArray(value.questions) && value.questions.length > 0 && value.questions.every((question) => isRecord(question) && typeof question.prompt === 'string' && Array.isArray(question.options) && question.options.length > 0 && question.options.every((option) => typeof option === 'string'))
}

export function ArtifactsLibrary({ preferences }: { preferences: LumiApplicationSettings }) {
  const [query, setQuery] = useState('')
  const [kind, setKind] = useState('All')
  const [selectedArtifactId, setSelectedArtifactId] = useState<string | null>(null)
  const artifacts = useQuery({ queryKey: lumiQueryKeys.artifacts, queryFn: getArtifacts })
  const normalizedQuery = query.trim().toLowerCase()
  const kinds = useMemo(() => ['All', ...new Set(artifacts.data?.map((item) => item.kind) ?? [])], [artifacts.data])
  const visibleArtifacts = useMemo(() => (artifacts.data ?? []).filter((item) => (
    (kind === 'All' || item.kind === kind) &&
    `${item.title} ${item.content} ${item.source}`.toLowerCase().includes(normalizedQuery)
  )).sort((a, b) => preferences.artifactSort === 'Oldest first' ? Date.parse(a.updatedAt) - Date.parse(b.updatedAt) : preferences.artifactSort === 'Title A–Z' ? a.title.localeCompare(b.title) : Date.parse(b.updatedAt) - Date.parse(a.updatedAt)), [artifacts.data, kind, normalizedQuery, preferences.artifactSort])
  const selectedArtifact = visibleArtifacts.find((item) => item.id === selectedArtifactId)

  return (
    <section className="artifact-library" aria-labelledby="library-title">
      <header className="library-header">
        <div><p className="eyebrow">Your library</p><h1 id="library-title">Your learning, collected.</h1><p>Every note, lesson, review, and study object Lumi creates stays available here.</p></div>
        <button className="library-refresh" type="button" onClick={() => artifacts.refetch()} disabled={artifacts.isFetching}>{artifacts.isFetching ? 'Refreshing…' : 'Refresh'}</button>
      </header>
      <label className="sr-only" htmlFor="artifact-search">Search artifacts</label>
      <div className="artifact-search"><Search aria-hidden="true" /><input id="artifact-search" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search titles, content, and sources" /></div>
      {!artifacts.isLoading && !artifacts.isError && <div className="artifact-filters" aria-label="Filter artifacts by type">{kinds.map((itemKind) => <button className={kind === itemKind ? 'is-active' : ''} type="button" key={itemKind} onClick={() => setKind(itemKind)}>{itemKind}<span>{itemKind === 'All' ? artifacts.data?.length ?? 0 : artifacts.data?.filter((item) => item.kind === itemKind).length ?? 0}</span></button>)}</div>}
      {artifacts.isLoading ? <div className="artifact-loading" aria-live="polite"><span className="loading-orb" aria-hidden="true" /><p>Opening your library…</p></div> : artifacts.isError ? (
        <section className="artifact-empty"><h2>Your library could not be loaded.</h2><p>Check the local service, then try again.</p><button type="button" onClick={() => artifacts.refetch()}>Try again</button></section>
      ) : visibleArtifacts.length ? (
        <div className="artifact-layout"><div className={`artifact-grid ${preferences.artifactLayout === 'list' ? 'is-list' : ''}`} aria-label={`${visibleArtifacts.length} saved artifacts`}>{visibleArtifacts.map((artifact) => <ArtifactCard artifact={artifact} key={artifact.id} selected={selectedArtifactId === artifact.id} onSelect={() => setSelectedArtifactId(artifact.id)} />)}</div>{selectedArtifact && <ArtifactDetail artifact={selectedArtifact} onClose={() => setSelectedArtifactId(null)} />}</div>
      ) : <section className="artifact-empty"><h2>{normalizedQuery ? 'No artifacts match that search.' : 'Your library is ready.'}</h2><p>{normalizedQuery ? 'Try a different title, source, or phrase.' : 'Generated notes, lessons, quizzes, flashcards, and revision plans will appear here.'}</p></section>}
    </section>
  )
}

function ArtifactCard({ artifact, selected, onSelect }: { artifact: LumiArtifact; selected: boolean; onSelect: () => void }) {
  return <button className={`artifact-card ${selected ? 'is-selected' : ''}`} type="button" onClick={onSelect} aria-pressed={selected}><span className="artifact-kind">{artifact.kind}</span><strong>{artifact.title}</strong><span className="artifact-summary">{artifact.content.trim() || 'Open this saved learning object.'}</span><small>{artifact.source || 'Lumi workspace'} · {new Date(artifact.updatedAt).toLocaleDateString()}</small></button>
}

function ArtifactDetail({ artifact, onClose }: { artifact: LumiArtifact; onClose: () => void }) {
  const learningObject = artifact.learningObject
  return <aside className="artifact-detail" aria-label={`Artifact details: ${artifact.title}`}><button className="small-icon-button" type="button" aria-label="Close artifact details" onClick={onClose}><X aria-hidden="true" /></button><p className="eyebrow">{artifact.kind}</p><h2>{artifact.title}</h2><p className="artifact-source">Source: {artifact.source || 'Lumi workspace'}</p>{isFlashcards(learningObject) ? <FlashcardPlayer cards={learningObject.cards} /> : isQuiz(learningObject) ? <QuizPlayer artifactId={artifact.id} questions={learningObject.questions} /> : <div className="artifact-content">{artifact.content}</div>}</aside>
}

function FlashcardPlayer({ cards }: { cards: Flashcard[] }) {
  const [cardIndex, setCardIndex] = useState(0)
  const [isRevealed, setRevealed] = useState(false)
  const card = cards[cardIndex]
  function moveTo(index: number) { setCardIndex(index); setRevealed(false) }
  return <section className="learning-player" aria-label="Flashcard practice"><p className="player-progress">Card {cardIndex + 1} of {cards.length}</p><div className="player-progress-track"><span style={{ width: `${((cardIndex + 1) / cards.length) * 100}%` }} /></div><p className="player-guidance">Recall the answer, then reveal it.</p><div className="flashcard"><p>Prompt</p><strong>{card.front}</strong>{isRevealed && <><hr /><p>Answer</p><span>{card.back}</span></>}</div><div className="player-actions"><button type="button" className="primary-player-action" onClick={() => setRevealed((revealed) => !revealed)}>{isRevealed ? 'Hide answer' : 'Reveal answer'}</button><button type="button" disabled={cardIndex === 0} onClick={() => moveTo(cardIndex - 1)}>Previous</button><button type="button" disabled={cardIndex === cards.length - 1} onClick={() => moveTo(cardIndex + 1)}>Next</button><button type="button" className="text-player-action" onClick={() => moveTo(0)}>Start over</button></div></section>
}

function QuizPlayer({ artifactId, questions }: { artifactId: string; questions: QuizQuestion[] }) {
  const [answers, setAnswers] = useState<Record<number, number>>({})
  const { mutate: submit, data: result, error, isPending, reset: resetSubmission } = useMutation<LumiQuizResult, Error, number[]>({ mutationFn: (submittedAnswers) => submitArtifactQuiz(artifactId, submittedAnswers) })
  const allAnswered = questions.every((_, index) => answers[index] !== undefined)
  function reset() { setAnswers({}); resetSubmission() }
  return <section className="learning-player" aria-label="Quiz practice"><p className="player-progress" aria-live="polite">{result ? `Score: ${result.score} / ${result.total}` : `${Object.keys(answers).length} of ${questions.length} answered`}</p>{questions.map((question, questionIndex) => <fieldset className="quiz-question" key={question.prompt}><legend>{questionIndex + 1}. {question.prompt}</legend>{question.options.map((option, optionIndex) => <label className={answers[questionIndex] === optionIndex ? 'is-selected' : ''} key={option}><input type="radio" name={`quiz-${artifactId}-${questionIndex}`} value={optionIndex} checked={answers[questionIndex] === optionIndex} disabled={isPending || Boolean(result)} onChange={() => setAnswers((current) => ({ ...current, [questionIndex]: optionIndex }))} /><span>{String.fromCharCode(65 + optionIndex)}. {option}</span></label>)}{result && <p className={result.feedback[questionIndex]?.correct ? 'quiz-feedback is-correct' : 'quiz-feedback'}>{result.feedback[questionIndex]?.correct ? 'Correct' : `Answer: ${String.fromCharCode(65 + result.feedback[questionIndex].answerIndex)}`} · {result.feedback[questionIndex]?.explanation}</p>}</fieldset>)}{error && <p className="save-error" role="alert">Your answers could not be checked. Try again.</p>}<div className="player-actions">{result ? <button type="button" className="primary-player-action" onClick={reset}>Try again</button> : <button type="button" className="primary-player-action" disabled={!allAnswered || isPending} onClick={() => submit(questions.map((_, index) => answers[index]))}>{isPending ? 'Checking…' : 'Check answers'}</button>}</div></section>
}
