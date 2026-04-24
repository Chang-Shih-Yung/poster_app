import PageShell from "@/components/PageShell";
import WorkForm from "./WorkForm";

export default function NewWorkPage() {
  return (
    <PageShell title="新增作品" showBack>
      <div className="px-4 py-4 md:px-0 md:py-0">
        <h1 className="hidden md:block text-2xl font-semibold mb-6">新增作品</h1>
        <WorkForm mode="create" />
      </div>
    </PageShell>
  );
}
